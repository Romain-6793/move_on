# frozen_string_literal: true

# Contrôleur Wicked pour le formulaire de création de recherche en 4 étapes.
#
# Wicked::Wizard est un module Ruby qui transforme un contrôleur Rails standard
# en "wizard" (parcours guidé). Il fournit :
#   - steps(*names)     : définit les étapes dans l'ordre
#   - render_wizard     : rend la vue de l'étape courante puis redirige vers la suivante
#   - wizard_path(step) : helper de chemin vers une étape donnée
#   - step              : nom de l'étape courante (Symbol)
#   - finish_wizard_path: méthode à surcharger pour définir la redirection finale
#
# Persistance inter-étapes : l'id du Research en cours de création est stocké
# en session (session[:wizard_research_id]). Cela évite de passer l'id dans l'URL
# et simplifie les routes.
#
# Chaque étape sauvegarde les données partielles via save(validate: false),
# ce qui permet d'enregistrer une recherche incomplète entre les étapes.
class SearchStepsController < ApplicationController
  include Wicked::Wizard

  # Les 4 étapes du parcours, dans l'ordre.
  steps :details, :essentials, :priorities, :confirm

  # ─── Affichage d'une étape ────────────────────────────────────────────────

  def show
    @research = load_research
    authorize @research, :update?
    # On charge les régions uniquement à l'étape 1 pour alimenter le dropdown.
    # distinct + order + compact évite les doublons, trie alphabétiquement et exclut les NULL.
    @regions = City.distinct.order(:nom_reg).pluck(:nom_reg).compact if step == :details
    render_wizard
  end

  # ─── Soumission d'une étape ───────────────────────────────────────────────

  def update
    @research = load_research

    case step
    when :details
      # Étape 1 : informations générales (nom, géographie, population).
      # Le Research est créé ici pour la première fois (ou mis à jour si on revient).
      @research.assign_attributes(details_params)
      @research.user ||= current_user   # association user déjà initialisée par build, mais sécurité
      authorize @research, :update?
      @research.save(validate: false)   # sauvegarde partielle : le nom peut encore être vide
      session[:wizard_research_id] = @research.id

    when :essentials
      # Étape 2 : critères essentiels (valeur 3 = essentiel, 0 = non retenu).
      authorize @research, :update?
      attrs = criteria_params
      attrs = parse_education_levels(attrs)
      @research.assign_attributes(attrs)
      @research.save(validate: false)

    when :priorities
      # Étape 3 : pondération des critères non-essentiels (2 = important, 1 = bonus, 0 = ignoré).
      # Les critères déjà marqués essentiels (valeur 3 en base) sont EXCLUS des paramètres
      # pour éviter de les écraser avec une valeur moindre.
      authorize @research, :update?
      attrs = criteria_params.reject { |key, _| @research.send(key) == 3 }
      @research.assign_attributes(attrs)
      @research.save(validate: false)

    when :confirm
      # Étape 4 : récapitulatif — rien à sauvegarder, on valide et on redirige.
      authorize @research, :update?
      # On force la validation complète pour signaler d'éventuelles incohérences
      # (ex : nom manquant si l'utilisateur a sauté l'étape 1 via URL directe).
      @research.save unless @research.persisted? && @research.valid?
    end

    render_wizard @research
  end

  # ─── Démarrer un nouveau wizard (lien navbar "Nouvelle recherche") ────────

  # Vide la session pour ne pas reprendre un wizard précédent, puis redirige
  # vers la première étape. Accessible via GET /recherche/nouveau.
  def new_wizard
    session.delete(:wizard_research_id)
    redirect_to wizard_path(:details)
  end

  private

  # ─── Chargement du Research ───────────────────────────────────────────────

  # Charge le Research en cours (depuis la session) ou en construit un nouveau
  # vide associé à l'utilisateur connecté.
  def load_research
    if session[:wizard_research_id]
      # find_by retourne nil si l'enregistrement n'existe pas (pas d'exception).
      current_user.researches.find_by(id: session[:wizard_research_id]) ||
        current_user.researches.build
    else
      # Nouveau wizard : l'objet n'est pas encore en base.
      current_user.researches.build
    end
  end

  # ─── Redirection finale ───────────────────────────────────────────────────

  # Appelée par Wicked après la dernière étape.
  # On nettoie la session et on redirige vers la page de résultats.
  def finish_wizard_path
    research = current_user.researches.find(session[:wizard_research_id])
    session.delete(:wizard_research_id)
    research_path(research)
  end

  # ─── Strong Parameters par étape ─────────────────────────────────────────

  # Étape 1 : champs généraux uniquement
  def details_params
    params.require(:research).permit(
      :research_name,
      :coast, :mountain, :no_filters,
      :density,
      :region
    )
  end

  # Étapes 2 et 3 : critères de sélection
  # Les critères partagent les mêmes colonnes entières (0/1/2/3) en base.
  def criteria_params
    params.require(:research).permit(
      :real_estate,
      :transport_network,
      :health,
      :commercial_life,
      :cultural_heritage,
      :leisures_and_sports,
      :outdoor_living,
      :sunshine,
      :job_market,
      :near_big_city,
      :education,
      :education_levels
    )
  end

  # Convertit la chaîne JSON d'education_levels en Array Ruby,
  # comme dans ResearchesController (même logique, centralisée ici).
  def parse_education_levels(attrs)
    if attrs[:education_levels].present?
      attrs[:education_levels] = JSON.parse(attrs[:education_levels])
    end
    attrs
  end
end
