# frozen_string_literal: true

# Contrôleur Wicked pour le wizard de recherche invité (visiteur non connecté).
#
# Miroir du SearchStepsController, mais :
#   - Pas d'authentification (skip_before_action)
#   - Utilise GuestSearch au lieu de Research (pas de user_id)
#   - Redirige vers les résultats invité en fin de wizard
#
# La session conserve l'id de la GuestSearch entre les 4 étapes,
# exactement comme le wizard utilisateur conserve :wizard_research_id.
class GuestSearchStepsController < ApplicationController
  include Wicked::Wizard

  # Le wizard invité est public par définition.
  skip_before_action :authenticate_user!

  # Même 4 étapes que le wizard utilisateur connecté.
  steps :details, :essentials, :priorities, :confirm

  # ─── Affichage d'une étape ────────────────────────────────────────────────

  def show
    @guest_search = load_guest_search
    render_wizard
  end

  # ─── Soumission d'une étape ───────────────────────────────────────────────

  def update
    @guest_search = load_guest_search

    case step
    when :details
      # Étape 1 : nom, géographie, population.
      # La GuestSearch est créée ici pour la première fois et son id stocké en session.
      @guest_search.assign_attributes(details_params)
      @guest_search.save(validate: false)
      session[:guest_search_id] = @guest_search.id

    when :essentials
      # Étape 2 : critères essentiels (valeur 3).
      attrs = criteria_params
      attrs = parse_education_levels(attrs)
      @guest_search.assign_attributes(attrs)
      @guest_search.save(validate: false)

    when :priorities
      # Étape 3 : pondération des critères non-essentiels.
      # On exclut les critères déjà essentiels (valeur 3) pour ne pas les écraser.
      attrs = criteria_params.reject { |key, _| @guest_search.send(key) == 3 }
      @guest_search.assign_attributes(attrs)
      @guest_search.save(validate: false)

    when :confirm
      # Étape 4 : récapitulatif — on sauvegarde uniquement si ce n'est pas déjà fait.
      @guest_search.save unless @guest_search.persisted? && @guest_search.valid?
    end

    render_wizard @guest_search
  end

  # ─── Démarrer un nouveau wizard invité ───────────────────────────────────

  # Supprime l'éventuelle GuestSearch précédente, vide la session et
  # redirige vers l'étape 1. Accessible via GET /recherche/invite/nouveau.
  def new_wizard
    if session[:guest_search_id]
      # On ne conserve qu'une seule GuestSearch par session (cohérence avec le flux existant).
      GuestSearch.find_by(id: session[:guest_search_id])&.destroy
      session.delete(:guest_search_id)
    end
    redirect_to wizard_path(:details)
  end

  private

  # ─── Chargement de la GuestSearch ────────────────────────────────────────

  # Charge la GuestSearch en cours depuis la session, ou en construit une nouvelle vide.
  def load_guest_search
    if session[:guest_search_id]
      GuestSearch.find_by(id: session[:guest_search_id]) || GuestSearch.new
    else
      GuestSearch.new
    end
  end

  # ─── Redirection finale ───────────────────────────────────────────────────

  # Wicked appelle finish_wizard_path après la dernière étape.
  # On redirige vers la page de résultats invité gérée par GuestSearchesController.
  def finish_wizard_path
    results_guest_searches_path
  end

  # ─── Strong Parameters par étape ─────────────────────────────────────────

  # Étape 1 : champs généraux uniquement.
  def details_params
    params.require(:guest_search).permit(
      :research_name,
      :coast, :mountain, :no_filters,
      :density
    )
  end

  # Étapes 2 et 3 : critères de sélection (mêmes colonnes que Research).
  def criteria_params
    params.require(:guest_search).permit(
      :real_estate,
      :transport_network,
      :health,
      :commercial_life,
      :cultural_heritage,
      :education,
      :leisures_and_sports,
      :education_levels
    )
  end

  # Convertit la chaîne JSON education_levels en Array Ruby avant l'assignation.
  # Le champ caché dans la vue transmet un JSON stringifié ; ActiveRecord attend un tableau.
  def parse_education_levels(attrs)
    if attrs[:education_levels].present?
      attrs[:education_levels] = JSON.parse(attrs[:education_levels])
    end
    attrs
  end
end
