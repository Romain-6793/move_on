class ChatsController < ApplicationController
 before_action :authenticate_user!
  before_action :set_chat, only: [:show, :destroy, :update]

  def index
    @chats = current_user.chats.order(updated_at: :desc)
    authorize @chat
  end

  def update
    if @chat.update(chat_params)
      redirect_back fallback_location: root_path, notice: "Titre modifié"
    else
      redirect_back fallback_location: root_path, alert: "Titre invalide"
    end
    authorize @chat
  end

  def show
    @chat = current_user.chats.find(params[:id])
    @messages = @chat.messages.order(created_at: :asc)
    @suggested_cities = City.where(id: session[:suggested_city_ids] || [])
    authorize @chat
  end

  def destroy
    @chat = current_user.chats.find(params[:id])
    @chat.destroy
    redirect_to root_path, notice: "Conversation supprimée"
    authorize @chat
  end

  private

  def chat_params
    params.require(:chat).permit(:title)
  end

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end
end
