class MapsController < ApplicationController
  # La carte est publique : un visiteur doit pouvoir la consulter sans compte.
  # skip_before_action annule le authenticate_user! hérité de ApplicationController
  # uniquement pour les actions listées dans :only.
  skip_before_action :authenticate_user!, only: [:index, :show]

  def index
    # respond_to permet de servir deux formats depuis la même action :
    # - HTML : la page avec la carte (rendue par index.html.erb)
    # - JSON : le GeoJSON consommé par le Stimulus controller via fetch()
    respond_to do |format|
      format.html
      format.json do
        # includes(:point_of_interests) évite les N+1 queries :
        # sans ça, chaque ville ferait une requête SQL séparée pour ses POIs.
        @cities = City.includes(:point_of_interests).all
      end
    end
  end

  def show
    
  end

end
