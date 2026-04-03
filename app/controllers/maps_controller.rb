class MapsController < ApplicationController
  # La carte est publique : un visiteur doit pouvoir la consulter sans compte.
  # skip_before_action annule le authenticate_user! hérité de ApplicationController
  # uniquement pour les actions listées dans :only.
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index

  end

  def show
    
  end

end
