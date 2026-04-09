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
    
  end

  def results
    
  end
end
