# frozen_string_literal: true

module UrbanAssist
  # Orchestre une interaction utilisateur → RubyLLM → persistance Message + session.
  class SendMessage
    SESSION_CHAT_KEY = :urban_assist_chat_id
    SESSION_SUGGESTED_CITIES_KEY = :suggested_city_ids

    # Limite l'historique envoyé au LLM (tokens + latence).
    MAX_PRIOR_MESSAGES = 24
    MAX_PRIOR_MESSAGE_CHARS = 6_000

    # Surcharge en test pour injecter un double LLM sans appeler RubyLLM.chat.
    cattr_accessor :llm_chat_entry_override, instance_accessor: false

    Result = Struct.new(:success, :error, :chat, :user_message, :assistant_message, :suggested_city_ids, keyword_init: true)

    def initialize(session:, content:, chat:)
      @session = session
      @content = content.to_s.strip
      @chat = chat
    end

    def call
      return Result.new(success: false, error: :blank_content) if @content.blank?
      return Result.new(success: false, error: :unauthorized_chat) if @chat.nil?

      user_message = nil
      assistant_message = nil

      ActiveRecord::Base.transaction do
        @chat.title = @content.truncate(50) if @chat.title.blank?
        @chat.save! if @chat.new_record? || @chat.changed?

        user_message = @chat.messages.create!(content: @content, role: "user")
      end

      llm_chat = build_llm_chat
      build_conversation_history(llm_chat, @chat, user_message)

      response = ask_with_tool_retry(llm_chat, @content, stream: false)

      city_ids = extract_city_ids_from_response(response)
      @session[SESSION_SUGGESTED_CITIES_KEY] = city_ids
      @session[SESSION_CHAT_KEY] = @chat.id

      ActiveRecord::Base.transaction do
        assistant_message = @chat.messages.create!(
          content: response.content.to_s,
          role: "assistant"
        )
      end

      Result.new(
        success: true,
        chat: @chat.reload,
        user_message: user_message,
        assistant_message: assistant_message,
        suggested_city_ids: @session[SESSION_SUGGESTED_CITIES_KEY]
      )
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn("[UrbanAssist::SendMessage] rate_limit: #{e.message}")
      Result.new(success: false, error: :rate_limit)
    rescue RubyLLM::PaymentRequiredError => e
      Rails.logger.warn("[UrbanAssist::SendMessage] quota: #{e.message}")
      Result.new(success: false, error: :quota)
    rescue RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError => e
      Rails.logger.warn("[UrbanAssist::SendMessage] unavailable: #{e.message}")
      Result.new(success: false, error: :service_unavailable)
    rescue Faraday::TimeoutError, Timeout::Error => e
      Rails.logger.warn("[UrbanAssist::SendMessage] timeout: #{e.message}")
      Result.new(success: false, error: :timeout)
    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error("[UrbanAssist::SendMessage] unauthorized: #{e.message}")
      Result.new(success: false, error: :unauthorized_api)
    rescue StandardError => e
      Rails.logger.error("[UrbanAssist::SendMessage] #{e.class}: #{e.message}")
      Result.new(success: false, error: :llm_or_database)
    end

    # Flux SSE : yield des hashes sérialisables pour MessagesController#stream.
    def stream_each_event
      return yield({ type: "error", code: "blank_content", message: "Message vide." }) if @content.blank?
      return yield({ type: "error", code: "unauthorized_chat", message: "Conversation introuvable." }) if @chat.nil?

      user_message = nil
      ActiveRecord::Base.transaction do
        @chat.title = @content.truncate(50) if @chat.title.blank?
        @chat.save! if @chat.new_record? || @chat.changed?

        user_message = @chat.messages.create!(content: @content, role: "user")
      end

      yield({ type: "user_message", message: message_payload(user_message) })

      llm_chat = build_llm_chat
      build_conversation_history(llm_chat, @chat, user_message)

      response = nil
      accumulated = +""

      if factual_query?(@content)
        response = ask_with_tool_retry(llm_chat, @content, stream: false)
        assistant_text = response.content.to_s
        simulate_token_stream(assistant_text) { |piece| yield({ type: "delta", text: piece }) }
      else
        response = ask_with_tool_retry(llm_chat, @content, stream: true) do |chunk|
          piece = chunk&.content
          next if piece.blank?

          accumulated << piece
          yield({ type: "delta", text: piece })
        end
        assistant_text = response&.content.to_s
        assistant_text = accumulated if assistant_text.blank? && accumulated.present?
      end

      city_ids = extract_city_ids_from_response(response)
      @session[SESSION_SUGGESTED_CITIES_KEY] = city_ids
      @session[SESSION_CHAT_KEY] = @chat.id

      assistant_message = nil
      ActiveRecord::Base.transaction do
        assistant_message = @chat.messages.create!(content: assistant_text, role: "assistant")
      end

      yield(
        {
          type: "done",
          chat_id: @chat.id,
          assistant_message: message_payload(assistant_message),
          suggested_city_ids: city_ids
        }
      )
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn("[UrbanAssist::SendMessage#stream] rate_limit: #{e.message}")
      yield({ type: "error", code: "rate_limit", message: "Trop de requêtes vers l’API. Réessayez dans un instant." })
    rescue RubyLLM::PaymentRequiredError => e
      Rails.logger.warn("[UrbanAssist::SendMessage#stream] quota: #{e.message}")
      yield({ type: "error", code: "quota", message: "Quota ou facturation API insuffisant." })
    rescue RubyLLM::ServiceUnavailableError, RubyLLM::OverloadedError => e
      Rails.logger.warn("[UrbanAssist::SendMessage#stream] unavailable: #{e.message}")
      yield({ type: "error", code: "service_unavailable", message: "Service IA temporairement indisponible." })
    rescue Faraday::TimeoutError, Timeout::Error => e
      Rails.logger.warn("[UrbanAssist::SendMessage#stream] timeout: #{e.message}")
      yield({ type: "error", code: "timeout", message: "Délai dépassé. Réessayez." })
    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error("[UrbanAssist::SendMessage#stream] unauthorized: #{e.message}")
      yield({ type: "error", code: "unauthorized_api", message: "Clé API invalide ou expirée." })
    rescue StandardError => e
      Rails.logger.error("[UrbanAssist::SendMessage#stream] #{e.class}: #{e.message}")
      yield({ type: "error", code: "llm_or_database", message: "Une erreur technique est survenue." })
    end

    def self.message_payload_for_controller(message)
      {
        id: message.id,
        role: message.role,
        content: message.content,
        html: ApplicationController.helpers.markdown(message.content)
      }
    end

    private

    def message_payload(message)
      self.class.message_payload_for_controller(message)
    end

    def build_llm_chat
      llm_entry = self.class.llm_chat_entry_override || -> { RubyLLM.chat }
      llm_entry.call
        .with_tools(UrbanAssist::CitiesTool)
        .with_temperature(0.2)
        .with_instructions(UrbanAssist::SystemPrompt::SYSTEM_PROMPT)
    end

    def ask_with_tool_retry(llm_chat, content, stream:, &chunk_handler)
      response = perform_ask(llm_chat, content, stream: stream, &chunk_handler)
      if needs_tool_enforcement_retry?(response, content)
        Rails.logger.info("[UrbanAssist::SendMessage] Retry : enforcement CitiesTool")
        nudge = "[Obligation : pour cette demande tu dois appeler l’outil CitiesTool avant toute donnée chiffrée ou liste de communes. Réponds en t’appuyant uniquement sur CitiesTool.] "
        response = perform_ask(llm_chat, "#{nudge}#{content}", stream: false)
      end
      response
    end

    def perform_ask(llm_chat, content, stream:, &chunk_handler)
      if stream
        raise ArgumentError, "stream requiert un bloc" unless block_given?

        llm_chat.ask(content, &chunk_handler)
      else
        llm_chat.ask(content)
      end
    end

    def factual_query?(text)
      text.match?(/\b(prix|m²|m2|€|euro|achat|vente|commune|ville|département|departement|région|region|budget|louer|acheter|médian|median|moyen|loyer|immobilier|estimation)\b/i)
    end

    def needs_tool_enforcement_retry?(response, user_content)
      return false unless factual_query?(user_content)
      return false if tool_calls_present?(response)

      true
    end

    def tool_calls_present?(response)
      return false unless response.respond_to?(:tool_calls)

      tc = response.tool_calls
      return false if tc.nil?

      tc.is_a?(Hash) ? tc.any? : tc.present?
    end

    def normalized_tool_calls(response)
      tc = response.tool_calls
      return [] if tc.nil?
      return tc.values if tc.is_a?(Hash)

      Array(tc)
    end

    def simulate_token_stream(text)
      return if text.blank?

      text.split(/(\s+)/).each do |piece|
        next if piece.blank?

        yield piece
      end
    end

    def build_conversation_history(llm_chat, chat, current_user_message)
      scope = chat.messages
        .where.not(id: current_user_message.id)
        .order(created_at: :desc)
        .limit(MAX_PRIOR_MESSAGES)

      scope.reverse_each do |message|
        body = message.content.to_s.truncate(MAX_PRIOR_MESSAGE_CHARS)
        role_sym = message.role.to_sym
        llm_chat.add_message(role: role_sym, content: body)
      end
    end

    def extract_city_ids_from_response(response)
      city_ids = []

      if tool_calls_present?(response)
        city_ids = normalized_tool_calls(response)
          .select { |tc| tc.tool_name.to_s.end_with?("CitiesTool") }
          .flat_map { |tc| tc.result.is_a?(Hash) ? tc.result["data"]&.map { |c| c["id"] || c[:id] } : [] }
          .compact
      end

      if city_ids.empty? && response.respond_to?(:content)
        city_ids = response.content.to_s.scan(/ID\s*:\s*(\d+)/).flatten.map(&:to_i)
      end

      city_ids.present? ? City.where(id: city_ids).pluck(:id) : []
    end
  end
end
