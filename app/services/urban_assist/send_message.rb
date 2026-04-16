# frozen_string_literal: true

module UrbanAssist
  # Orchestre une interaction utilisateur → RubyLLM → persistance Message + session.
  class SendMessage
    SESSION_CHAT_KEY = :urban_assist_chat_id
    SESSION_SUGGESTED_CITIES_KEY = :suggested_city_ids

    # Surcharge en test pour injecter un double LLM sans appeler RubyLLM.chat.
    cattr_accessor :llm_chat_entry_override, instance_accessor: false

    Result = Struct.new(:success, :error, :chat, :user_message, :assistant_message, :suggested_city_ids, keyword_init: true)

    def initialize(user:, session:, content:, chat:)
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

        llm_entry = self.class.llm_chat_entry_override || -> { RubyLLM.chat }
        llm_chat = llm_entry.call
          .with_tools(UrbanAssist::CitiesTool)
          .with_temperature(0.2)

        build_conversation_history(llm_chat, @chat, user_message)

        response = llm_chat
          .with_instructions(UrbanAssist::SystemPrompt::SYSTEM_PROMPT)
          .ask(@content)

        city_ids = extract_city_ids_from_response(response)
        @session[SESSION_SUGGESTED_CITIES_KEY] = city_ids
        @session[SESSION_CHAT_KEY] = @chat.id

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
    rescue StandardError => e
      Rails.logger.error("[UrbanAssist::SendMessage] #{e.class}: #{e.message}")
      Result.new(success: false, error: :llm_or_database)
    end

    private

    def build_conversation_history(llm_chat, chat, current_user_message)
      chat.messages.where.not(id: current_user_message.id).order(:created_at).find_each do |message|
        llm_chat.add_message(message)
      end
    end

    def extract_city_ids_from_response(response)
      city_ids = []

      if response.respond_to?(:tool_calls) && response.tool_calls.present?
        city_ids = response.tool_calls
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
