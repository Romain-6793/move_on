# frozen_string_literal: true

class UsersController < ApplicationController
  def show
    @user = current_user
    authorize @user
    # On précharge les recherches pour éviter un N+1 query dans la vue
    @researches = @user.researches
  end

  def update
    @user = current_user
    authorize @user

    if @user.update(user_params)
      redirect_to profile_user_path(@user), notice: "Profil mis à jour avec succès."
    else
      # En cas d'erreur de validation, on réaffiche la page profil avec les erreurs
      @researches = @user.researches
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @user = current_user
    authorize @user

    @user.destroy
    # On déconnecte l'utilisateur après suppression (méthode Devise)
    sign_out @user
    redirect_to root_path, notice: "Votre compte a été supprimé définitivement."
  end

  private

  # Strong parameters : on liste explicitement les champs autorisés.
  # L'email et le mot de passe sont gérés séparément par Devise.
  def user_params
    params.require(:user).permit(
      :firstname,
      :lastname,
      :date_of_birth,
      :situation,
      :relocation_project
    )
  end
end
