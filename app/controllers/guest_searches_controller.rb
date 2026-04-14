# frozen_string_literal: true

class GuestSearchesController < ApplicationController
  # Le formulaire de recherche invité est public par définition :
  # c'est l'outil pour les visiteurs qui n'ont pas encore de compte.
  # On exclut également :create et :results pour que le parcours complet
  # (saisie → envoi → affichage des résultats) fonctionne sans connexion.
  skip_before_action :authenticate_user!, only: [:new, :create, :results]

  def new
    @guest_search = GuestSearch.new
  end

  def create
    # Règle d'unicité : on ne conserve qu'une seule GuestSearch par visiteur.
    # Si une recherche précédente existe en base pour cette session, on la supprime
    # avant d'en créer une nouvelle. find_by retourne nil si introuvable (pas d'exception).
    if session[:guest_search_id]
      GuestSearch.find_by(id: session[:guest_search_id])&.destroy
    end

    @guest_search = GuestSearch.new(guest_search_params)

    if @guest_search.save
      # On stocke l'id en session pour pouvoir retrouver (et supprimer) cette recherche
      # lors de la prochaine visite ou à la fin de la session.
      session[:guest_search_id] = @guest_search.id
      redirect_to results_guest_searches_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def results
    # On charge la GuestSearch depuis la session pour afficher les résultats.
    @guest_search = GuestSearch.find_by(id: session[:guest_search_id])

    # Guard clause : `return` arrête l'exécution AVANT que Rails tente de rendre
    # la vue (sans `return`, le code suivant planterait car @guest_search serait nil).
    return redirect_to new_guest_search_path unless @guest_search

    @ranked_cities = CityRankerService.new(@guest_search).top_cities

    # On pré-charge les images manquantes avant le rendu de la vue.
    # Au premier passage : jusqu'à 5 appels Unsplash (1 par ville).
    # Les fois suivantes : image_url déjà en base → aucun appel réseau.
    @ranked_cities.each { |city| CityImageFetcherService.new(city).call }
  end

  private

  # Même périmètre que research_params : les critères actifs + les filtres géographiques.
  # Pas de user_id : les GuestSearch n'appartiennent à aucun compte.
  def guest_search_params
    params.require(:guest_search).permit(
      :research_name,
      :coast, :mountain, :no_filters, :density,
      :real_estate, :transport_network, :cultural_heritage,
      :health, :commercial_life, :leisures_and_sports
    )
  end
end
