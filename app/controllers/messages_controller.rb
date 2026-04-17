# frozen_string_literal: true

class MessagesController < ApplicationController
  include ActionController::Live

  before_action :authenticate_user!

  def create
    respond_to do |format|
      format.json { create_json }
      format.html { head :not_acceptable }
    end
  end

  # Réponses SSE pour le widget (streaming RubyLLM + deltas texte).
  def stream
    chat = chat_for_authorization
    if chat.nil?
      head :not_found
      return
    end

    authorize chat, :create?, policy_class: MessagePolicy

    response.headers["Content-Type"] = "text/event-stream; charset=utf-8"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    service = UrbanAssist::SendMessage.new(
      session: session,
      content: message_params[:content].to_s.strip,
      chat: chat
    )

    service.stream_each_event do |event|
      response.stream.write("data: #{event.to_json}\n\n")
    end
  rescue IOError
    # client a fermé la connexion
  ensure
    response.stream&.close
  end

  private

  def create_json
    chat = chat_for_authorization
    if chat.nil?
      render json: { ok: false, error: "unknown_chat" }, status: :not_found
      return
    end

    authorize chat, :create?, policy_class: MessagePolicy

    content = message_params[:content].to_s.strip
    result = UrbanAssist::SendMessage.new(
      session: session,
      content: content,
      chat: chat
    ).call

    unless result.success
      code, status = error_response_for(result.error)
      render json: { ok: false, error: code }, status: status
      return
    end

    render json: {
      ok: true,
      chat_id: result.chat.id,
      user_message: message_json(result.user_message),
      assistant_message: message_json(result.assistant_message),
      suggested_city_ids: result.suggested_city_ids
    }
  end

  def error_response_for(error_sym)
    case error_sym
    when :blank_content
      ["blank_content", :unprocessable_entity]
    when :rate_limit
      ["rate_limit", :too_many_requests]
    when :quota
      ["quota", :payment_required]
    when :service_unavailable
      ["service_unavailable", :service_unavailable]
    when :timeout
      ["timeout", :gateway_timeout]
    when :unauthorized_api
      ["unauthorized_api", :bad_gateway]
    else
      ["llm_or_database", :internal_server_error]
    end
  end

  def chat_for_authorization
    permitted_chat_id = params.permit(:chat_id)[:chat_id]
    cid = permitted_chat_id.presence || session[UrbanAssist::SendMessage::SESSION_CHAT_KEY]
    if cid.present?
      found = current_user.chats.find_by(id: cid)
      return found if found
      return nil if permitted_chat_id.present?

      current_user.chats.build
    else
      current_user.chats.build
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def message_json(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      html: helpers.markdown(message.content)
    }
  end
end
