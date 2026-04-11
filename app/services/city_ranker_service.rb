# frozen_string_literal: true

# CityRankerService – calcule un score composite pour chaque ville en SQL
# et retourne les N meilleures selon les critères d'une recherche.
#
# Pourquoi un service object plutôt que de la logique dans le contrôleur ?
# → Le calcul de score mélange logique métier et construction de requête.
#   Un service object isole cette complexité, la rend testable indépendamment,
#   et garde les contrôleurs minces (principe "Fat Models, Skinny Controllers").
#
# Compatible avec Research (utilisateur connecté) et GuestSearch (visiteur anonyme) :
# les deux modèles partagent exactement les mêmes colonnes de critères.
class CityRankerService
  # Correspondance champ du formulaire → colonne de score sur City (0-100).
  # On isole cette table en constante pour éviter de la dupliquer entre
  # le service (calcul) et la vue (affichage des jauges).
  CRITERIA_MAPPING = {
    real_estate:         "real_estate_score",
    transport_network:   "transport_network_score",
    cultural_heritage:   "cultural_heritage_score",
    health:              "health_score",
    commercial_life:     "commercial_life_score",
    leisures_and_sports: "leisures_sports_score"
  }.freeze

  # Bonus accordé quand le paysage ou la population correspond au filtre.
  # Poids 4 × score max 100 = 400, cohérent avec le score max d'un critère
  # essentiel (poids 3 × score 100 = 300), soit légèrement supérieur.
  GEOGRAPHY_BONUS = 400

  def initialize(search)
    # @search peut être un Research ou un GuestSearch – duck typing.
    @search = search
  end

  # Retourne une ActiveRecord::Relation de City triée par score décroissant.
  # Chaque ville expose l'attribut virtuel `computed_score` (calculé en SQL).
  # Le calcul en SQL évite de charger toutes les villes en mémoire Ruby.
  def top_cities(limit: 5)
    City.select("cities.*, (#{score_expression}) AS computed_score")
        .order("computed_score DESC")
        .limit(limit)
  end

  private

  # Assemble l'expression SQL du score composite.
  # On filtre les parties nil (critères inactifs ou filtres non sélectionnés)
  # et on les joint par addition.
  def score_expression
    parts = [landscape_sql, population_sql].compact
    parts.concat(criteria_sql_parts)

    # Si aucun filtre ni critère n'est actif, toutes les villes ont un score de 0
    # et seront renvoyées dans l'ordre de la base (acceptable pour le cas d'usage).
    parts.join(" + ").presence || "0"
  end

  # +400 si le type de paysage de la ville correspond au filtre choisi.
  # Renvoie nil si "indifférent" est sélectionné → aucun bonus paysage.
  # ILIKE est insensible à la casse, ce qui sécurise les variations d'encodage CSV.
  def landscape_sql
    return nil if @search.no_filters?

    if @search.coast?
      "CASE WHEN paysage ILIKE '%mer%' " \
      "OR paysage ILIKE '%littoral%' " \
      "OR paysage ILIKE '%côte%' " \
      "THEN #{GEOGRAPHY_BONUS} ELSE 0 END"
    elsif @search.mountain?
      "CASE WHEN paysage ILIKE '%montagne%' " \
      "OR paysage ILIKE '%alpin%' " \
      "OR paysage ILIKE '%massif%' " \
      "THEN #{GEOGRAPHY_BONUS} ELSE 0 END"
    end
  end

  # +400 si la ville atteint le seuil de population minimale souhaité.
  # density == 0 signifie "toutes tailles" : pas de filtre, pas de bonus.
  # .to_i est appelé pour garantir un entier dans le SQL (pas d'injection).
  def population_sql
    threshold = @search.density.to_i
    return nil if threshold.zero?

    "CASE WHEN population >= #{threshold} THEN #{GEOGRAPHY_BONUS} ELSE 0 END"
  end

  # Génère un terme SQL par critère actif (poids 1, 2 ou 3).
  # filter_map itère ET filtre en un seul passage (idiome Ruby moderne).
  # COALESCE(..., 0) remplace les scores NULL par 0 pour ne pas casser l'addition.
  def criteria_sql_parts
    CRITERIA_MAPPING.filter_map do |field, column|
      weight = @search.public_send(field).to_i
      next if weight.zero?

      "(#{weight} * COALESCE(#{column}, 0))"
    end
  end
end
