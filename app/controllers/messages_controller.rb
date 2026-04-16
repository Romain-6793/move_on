# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    respond_to do |format|
      format.json { create_json }
      format.html { head :not_acceptable }
    end
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
      user: current_user,
      session: session,
      content: content,
      chat: chat
    ).call

    unless result.success
      status = result.error == :blank_content ? :unprocessable_entity : :internal_server_error
      render json: { ok: false, error: result.error.to_s }, status: status
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
