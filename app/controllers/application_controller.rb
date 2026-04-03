class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  include Pundit::Authorization
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  # On skip pundit quand il s'agit d'admin controllers (pas encore utilisés ici)
  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end

  protected

  def after_sign_up_path_for(resource)
    profile_user_path(resource)
  end

  def after_sign_in_path_for(resource)
    profile_user_path(resource)
  end

  # Les permitted parameters doivent être précisés, ce sont les champs en plus rajoutés à
  # l'inscription, on les précise pour le sign-up et la màj du compte.

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :firstname,
      :lastname,
      :date_of_birth,
      :situation,
      :single
    ])

    devise_parameter_sanitizer.permit(:account_update, keys: [
      :firstname,
      :lastname,
      :date_of_birth,
      :situation,
      :single
    ])
  end

end
