# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: [:show, :destroy, :update]

  def index
    @chats = policy_scope(Chat).order(updated_at: :desc)
    authorize Chat
  end

  def update
    authorize @chat
    if @chat.update(chat_params)
      redirect_back fallback_location: root_path, notice: "Titre modifié"
    else
      redirect_back fallback_location: root_path, alert: "Titre invalide"
    end
  end

  def show
    authorize @chat
    @messages = @chat.messages.order(created_at: :asc)
    @suggested_cities = City.where(id: session[:suggested_city_ids] || [])

    respond_to do |format|
      format.html { redirect_to profile_user_path(current_user), notice: "Utilisez l'assistant depuis l'icône en bas à droite." }
      format.json do
        render json: {
          chat_id: @chat.id,
          messages: @messages.map { |m| message_hash(m) }
        }
      end
    end
  end

  def destroy
    authorize @chat
    @chat.destroy

    # On réinitialise aussi les clés de session liées à l'assistant : sans ça,
    # le prochain message utiliserait encore l'ID du chat supprimé côté serveur
    # (fallback dans MessagesController#chat_for_authorization) et les villes
    # suggérées resteraient celles de l'ancienne conversation.
    session.delete(UrbanAssist::SendMessage::SESSION_CHAT_KEY)
    session.delete(UrbanAssist::SendMessage::SESSION_SUGGESTED_CITIES_KEY)

    respond_to do |format|
      # HTML conservé pour les usages existants (liste des conversations).
      format.html { redirect_to root_path, notice: "Conversation supprimée" }
      # JSON pour le widget chatbot : pas de contenu à renvoyer, le client
      # se charge de vider son DOM et sa sessionStorage.
      format.json { head :no_content }
    end
  end

  private

  def chat_params
    params.require(:chat).permit(:title)
  end

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end

  def message_hash(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      html: helpers.markdown(message.content)
    }
  end
end
