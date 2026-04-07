class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :home
  def home
  end

  def profile
    # GET /profile redirige vers la vraie page profil de l'utilisateur connecté.
    # On garde la route pour les liens existants, mais la vue est supprimée (doublon).
    redirect_to profile_user_path(current_user)
  end
end
