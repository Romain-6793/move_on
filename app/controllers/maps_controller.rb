# frozen_string_literal: true

class MapsController < ApplicationController
  # La carte est publique : un visiteur doit pouvoir la consulter sans compte.
  # skip_before_action annule le authenticate_user! hérité de ApplicationController
  # uniquement pour les actions listées dans :only.
  skip_before_action :authenticate_user!, only: [:index, :show, :results]

  # Liste blanche des types de POI acceptés — élimine toute valeur inconnue
  # venant d'un query param ?kinds= pour éviter des requêtes SQL inattendues.
  VALID_POI_KINDS = %w[sport culture nature commerce transport education health].freeze

  # Correspondance entre les critères de recherche (Research/GuestSearch)
  # et les types de POI stockés en base.
  # real_estate, sunshine etc. n'ont pas de POI kind associé → exclus.
  CRITERIA_TO_POI_KIND = {
    transport_network:   "transport",
    cultural_heritage:   "culture",
    health:              "health",
    commercial_life:     "commerce",
    leisures_and_sports: "sport",
    education:           "education"
  }.freeze

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
        authorize @cities
      end
    end
  end

  def show
    # includes pour éviter les N+1 si on accède aux POIs depuis la ville
    @city = City.includes(:point_of_interests).find(params[:id])
    authorize @city

    # Extrait les types de POI demandés via le query param ?kinds=transport,health
    # L'intersection (&) avec VALID_POI_KINDS élimine toute valeur non autorisée.
    @poi_kinds = params[:kinds].to_s.split(",").map(&:strip) & VALID_POI_KINDS

    # Rang de la ville dans le classement des 5 meilleures, propagé depuis
    # les city_cards de la page résultats via le query param ?rank=1…5.
    # On valide la plage [1..5] côté contrôleur (source contrôlée) : toute
    # valeur hors plage est ignorée et la carte affichera le marqueur par défaut.
    rank = params[:rank].to_i
    @city_rank = (1..5).cover?(rank) ? rank : nil

    # Si des types sont spécifiés on filtre, sinon on prend tous les POIs de la ville.
    pois = @poi_kinds.any? ? @city.point_of_interests.where(kind: @poi_kinds) : @city.point_of_interests

    # On sérialise les POIs en features GeoJSON pour le controller Stimulus.
    # Passé en inline dans la vue via data-map-pois-value — pas d'appel réseau supplémentaire.
    @pois_features = pois.map do |poi|
      {
        type:     "Feature",
        geometry: { type: "Point", coordinates: [poi.longitude, poi.latitude] },
        properties: {
          id:        poi.id,
          name:      poi.name,
          kind:      poi.kind,
          category:  poi.category,
          public:    poi.public,
          city_name: @city.nom_com
        }
      }
    end
  end

  # Action dédiée à la carte des résultats d'une recherche.
  # Affiche les 5 villes classées avec des marqueurs personnalisés (rang + nom).
  # Accessible sans connexion pour les visiteurs ayant une GuestSearch en session.
  def results
    if params[:research_id].present?
      # Utilisateur connecté : charge la recherche depuis l'id passé en paramètre.
      # ResearchPolicy#show? vérifie que current_user est bien le propriétaire.
      @research = Research.find(params[:research_id])
      authorize @research
      search = @research
    elsif session[:guest_search_id].present?
      # Visiteur anonyme : la recherche invitée est stockée en session (pas d'authentification).
      @guest_search = GuestSearch.find_by(id: session[:guest_search_id])
      return redirect_to root_path unless @guest_search

      # GuestSearchPolicy#results? retourne true — accessible à tout le monde.
      authorize @guest_search, :results?
      search = @guest_search
    else
      # Aucun contexte de recherche disponible → redirige vers la carte générale.
      return redirect_to maps_path
    end

    @ranked_cities = CityRankerService.new(search).top_cities
    @poi_kinds     = selected_poi_kinds(search)
    @search_name   = search.research_name.presence || "Vos résultats"

    # Données minimales des 5 villes sérialisées pour le controller Stimulus (inline JSON).
    # On évite de passer les gros objets ActiveRecord directement en JSON.
    @cities_data = @ranked_cities.map.with_index(1) do |city, rank|
      {
        id:        city.id,
        nom_com:   city.nom_com,
        nom_dep:   city.nom_dep.to_s,
        nom_reg:   city.nom_reg.to_s,
        latitude:  city.latitude,
        longitude: city.longitude,
        rank:      rank
      }
    end
  end

  private

  # Retourne les types de POI correspondant aux critères "essentiels" (valeur = 3)
  # du user dans sa recherche. Utilisé pour pré-filtrer les POIs sur la carte.
  #
  # Pourquoi valeur == 3 ? L'étape 2 du wizard ("Critères essentiels") stocke 3
  # pour chaque critère coché. Les valeurs 1 et 2 correspondent à des priorités
  # moindres (étape 3 "Priorités") et ne sont pas considérées comme "essentiels".
  def selected_poi_kinds(search)
    CRITERIA_TO_POI_KIND.filter_map do |key, kind|
      kind if search.public_send(key).to_i == 3
    end
  end
end
