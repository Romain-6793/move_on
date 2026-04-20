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
  #
  # Note : l'éducation est intentionnellement absente ici.
  # Son score est calculé dynamiquement par education_sql (combinaison de
  # sous-critères : crèches, premier degré, second degré) plutôt que depuis
  # la colonne statique cities.education_score. Voir education_score_part.
  CRITERIA_MAPPING = {
    real_estate:         "real_estate_score",
    transport_network:   "transport_network_score",
    cultural_heritage:   "cultural_heritage_score",
    health:              "health_score",
    commercial_life:     "commercial_life_score",
    leisures_and_sports: "leisures_sports_score",
    outdoor_living:      "outdoor_living_score"
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
  # On insère dans la requête les calculs particuliers comme education_score
  def top_cities(limit: 5)
    # On génère la partie SQL du score éducation (ou "0" si aucun niveau choisi)
    education_part = education_sql || "0"
    sunshine_part = normalized_sunshine_sql || "0"
    job_market_part = normalized_job_market_sql || "0"
    proximity_part = normalized_proximity_sql || "0"
    

    City.select("cities.*, (#{score_expression}) AS computed_score, 
    (#{education_part}) AS education_score, 
    (#{sunshine_part}) AS sunshine_score, 
    (#{job_market_part}) AS job_market_score,
    (#{proximity_part}) AS nearest_big_city_score 
    ") 
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

    # L'éducation est ajoutée séparément car son calcul est dynamique :
    # il dépend des niveaux scolaires sélectionnés (crèches, premier ou second degré).
    # On ne peut pas utiliser la colonne statique cities.education_score ici,
    # car elle ne reflète pas ces sous-critères.
    parts << education_score_part if education_score_part
    parts << sunshine_score_part if sunshine_score_part
    parts << job_market_score_part if job_market_score_part
    parts << proximity_score_part if proximity_score_part

    # Si aucun filtre ni critère n'est actif, toutes les villes ont un score de 0
    # et seront renvoyées dans l'ordre de la base (acceptable pour le cas d'usage).
    parts.join(" + ").presence || "0"
  end

  # Construit la contribution de l'éducation au score composite,
  # en s'appuyant sur education_sql (calcul dynamique par niveaux).
  # Retourne nil si l'éducation n'est pas sélectionnée ou si aucun niveau n'est choisi.
  def education_score_part
    # Mémoïsation : on ne calcule qu'une seule fois pour éviter d'appeler
    # education_sql deux fois (une pour le score, une pour l'affichage).
    return @education_score_part if defined?(@education_score_part)

    weight = @search.education.to_i
    edu_sql = education_sql

    # Si pas de poids ou pas de niveaux sélectionnés, aucune contribution
    @education_score_part = if weight.positive? && edu_sql
      # COALESCE(..., 0) protège contre les villes où nb_creche est NULL
      "(#{weight} * COALESCE(#{edu_sql}, 0))"
    end
  end

  def sunshine_score_part
    return @sunshine_score_part if defined?(@sunshine_score_part)

    weight = @search.sunshine.to_i
    sunshine_sql = normalized_sunshine_sql

    # Si pas de poids ou pas de niveaux sélectionnés, aucune contribution
    # Attention : bien écrire @sunshine_score_part ici (pas @education_score_part,
    # qui était la faute de frappe originelle cassant la mémoïsation).
    @sunshine_score_part = if weight.positive? && sunshine_sql
      "(#{weight} * COALESCE(#{sunshine_sql}, 0))"
    end
  end

  def job_market_score_part
    return @job_market_score_part if defined?(@job_market_score_part)

    weight = @search.job_market.to_i
    job_market_sql = normalized_job_market_sql

    # Si pas de poids ou pas de niveaux sélectionnés, aucune contribution
    @job_market_score_part = if weight.positive? && job_market_sql
      # COALESCE(..., 0) protège contre les villes où nb_creche est NULL
      "(#{weight} * COALESCE(#{job_market_sql}, 0))"
    end
  end

  def proximity_score_part
    return @proximity_score_part if defined?(@proximity_score_part)

    weight = @search.near_big_city.to_i
    proximity_sql = normalized_proximity_sql

    # Si pas de poids ou pas de niveaux sélectionnés, aucune contribution
    @proximity_score_part = if weight.positive? && proximity_sql
      # COALESCE(..., 0) protège contre les villes où nb_creche est NULL
      "(#{weight} * COALESCE(#{proximity_sql}, 0))"
    end
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

  def education_sql
    levels = @search.education_levels

    # Si l'utilisateur n'a sélectionné aucun niveau, on utilise les trois catégories
    # par défaut afin que la jauge "Education" soit toujours visible dans les city cards.
    # Cela n'influe pas sur le score composite : education_score_part vérifie
    # séparément que l'éducation est un critère actif (poids > 0).
    levels = ["Petite enfance", "Premier degré", "Second degré"] if levels.blank?

    parts = []

    # Petite enfance → normalisation SQL du nombre de crèches.
    # COALESCE(..., 0) est indispensable : nb_creche peut être NULL pour certaines villes,
    # et NULL + n'importe quoi = NULL en SQL, ce qui ferait tomber toute la moyenne à NULL.
    parts << "COALESCE(#{normalized_nurseries_sql}, 0)" if levels.include?("Petite enfance")

    # Premier degré → score déjà normalisé en base
    parts << "COALESCE(first_deg_score, 0)" if levels.include?("Premier degré")

    # Second degré → score déjà normalisé en base
    parts << "COALESCE(second_deg_score, 0)" if levels.include?("Second degré")

    # Garde-fou : si levels contenait des valeurs non reconnues uniquement
    return nil if parts.empty?

    # Moyenne des sous-critères sélectionnés.
    "( (#{parts.join(' + ')}) / #{parts.size} )"
  end

  # squish évite les caractères inutiles (retours à la ligne et espaces), NULLIF évite une division par 0

  def normalized_nurseries_sql
    <<~SQL.squish
      (
        100.0 * (
          CAST(nb_creche AS INTEGER)
          - (SELECT MIN(nb_creche) FROM cities)
          ) / NULLIF(
          (SELECT MAX(nb_creche) FROM cities) -
          (SELECT MIN(nb_creche) FROM cities),
          0
        )
      )
    SQL
  end

  def normalized_sunshine_sql
    <<~SQL.squish
      (
        100.0 * (
          (SELECT MAX(moy_nb_jou) FROM cities)
          - CAST(moy_nb_jou AS INTEGER)
        ) / NULLIF(
          (SELECT MAX(moy_nb_jou) FROM cities) -
          (SELECT MIN(moy_nb_jou) FROM cities),
          0
        )
      )
    SQL
  end

  def normalized_job_market_sql
    <<~SQL.squish
      (
        100.0 * (
          (SELECT MAX(chom_24) FROM cities)
          - CAST(chom_24 AS INTEGER)
        ) / NULLIF(
          (SELECT MAX(chom_24) FROM cities) -
          (SELECT MIN(chom_24) FROM cities),
          0
        )
      )
    SQL
  end

  def normalized_proximity_sql
    # taille_unite_urbaine va de 0 (commune rurale isolée) à 8 (métropole).
    # On normalise linéairement sur 0-100 en divisant par 8.
    # Avant le fix : un CASE qui donnait 0 aux valeurs 0-5 (78 % des communes),
    # ce qui faisait que toutes les city_cards affichaient 0%.
    # COALESCE(..., 0) évite NULL pour les communes sans donnée INSEE.
    <<~SQL.squish
      (100.0 * COALESCE(cities.taille_unite_urbaine, 0) / 8.0)
    SQL
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
