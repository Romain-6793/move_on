# frozen_string_literal: true

module UrbanAssist
  # Outil RubyLLM : lecture seule sur la table `cities` (données Move On).
  class CitiesTool < RubyLLM::Tool
    DEPARTMENT_MAPPING = {
      "ain" => "01", "aisne" => "02", "allier" => "03", "alpes-de-haute-provence" => "04",
      "hautes-alpes" => "05", "alpes-maritimes" => "06", "ardeche" => "07", "ardennes" => "08",
      "ariege" => "09", "aube" => "10", "aude" => "11", "aveyron" => "12",
      "bouches-du-rhone" => "13", "calvados" => "14", "cantal" => "15", "charente" => "16",
      "charente-maritime" => "17", "cher" => "18", "correze" => "19", "corse-du-sud" => "2A",
      "haute-corse" => "2B", "cote-d-or" => "21", "cotes-d-armor" => "22", "creuse" => "23",
      "dordogne" => "24", "doubs" => "25", "drome" => "26", "eure" => "27",
      "eure-et-loir" => "28", "finistere" => "29", "gard" => "30", "haute-garonne" => "31",
      "gers" => "32", "gironde" => "33", "herault" => "34", "ille-et-vilaine" => "35",
      "indre" => "36", "indre-et-loire" => "37", "isere" => "38", "jura" => "39",
      "landes" => "40", "loir-et-cher" => "41", "loire" => "42", "haute-loire" => "43",
      "loire-atlantique" => "44", "loiret" => "45", "lot" => "46", "lot-et-garonne" => "47",
      "lozere" => "48", "maine-et-loire" => "49", "manche" => "50", "marne" => "51",
      "haute-marne" => "52", "mayenne" => "53", "meurthe-et-moselle" => "54", "meuse" => "55",
      "morbihan" => "56", "moselle" => "57", "nievre" => "58", "nord" => "59",
      "oise" => "60", "orne" => "61", "pas-de-calais" => "62", "puy-de-dome" => "63",
      "pyrenees-atlantiques" => "64", "hautes-pyrenees" => "65", "pyrenees-orientales" => "66",
      "bas-rhin" => "67", "haut-rhin" => "68", "rhone" => "69", "haute-saone" => "70",
      "saone-et-loire" => "71", "sarthe" => "72", "savoie" => "73", "haute-savoie" => "74",
      "paris" => "75", "seine-maritime" => "76", "seine-et-marne" => "77", "yvelines" => "78",
      "deux-sevres" => "79", "somme" => "80", "tarn" => "81", "tarn-et-garonne" => "82",
      "var" => "83", "vaucluse" => "84", "vendee" => "85", "vienne" => "86",
      "haute-vienne" => "87", "vosges" => "88", "yonne" => "89", "territoire-de-belfort" => "90",
      "essonne" => "91", "hauts-de-seine" => "92", "seine-saint-denis" => "93",
      "val-de-marne" => "94", "val-d-oise" => "95", "guadeloupe" => "971",
      "martinique" => "972", "guyane" => "973", "la-reunion" => "974", "mayotte" => "976"
    }.freeze

    description <<~DESC
      Récupère des données immobilières depuis la table cities (base Move On).

      IMPORTANT - FORMAT DES PRIX :
      - avg_price_sqm et median_price_sqm sont en euros par m² (nombre entier affichable sans séparateur de milliers)
      - price_evolution_1y et price_evolution_3y sont en pourcentage

      CHAMPS DISPONIBLES (extrait aligné sur le schéma) :
      - insee : code INSEE commune
      - nom_com : nom de la commune
      - dep : code département ; nom_dep : nom du département
      - reg : code région ; nom_reg : nom de la région
      - avg_price_sqm, median_price_sqm, total_transactions, transactions_last_year
      - price_evolution_1y, price_evolution_3y
      - avg_rent_sqm, rent_quality, nb_obs_commune
      - population, population_density

      SÉLECTION :
      Pour département ou région, retourne au plus 5 villes les plus pertinentes après tri.
    DESC

    param :zone_type, desc: "commune, departement, region ou national"
    param :zone_name, desc: "Nom de la zone (optionnel)", required: false
    param :sort_by, desc: "Critère de tri : price_asc, price_desc, transactions, evolution (optionnel)", required: false
    param :min_population, desc: "Population minimum (optionnel)", required: false

    def execute(zone_type:, zone_name: nil, sort_by: nil, min_population: nil)
      scope = resolve_scope(zone_type, zone_name)
      if scope.blank?
        Rails.logger.info("[UrbanAssist::CitiesTool] Aucune donnée pour #{zone_type} / #{zone_name}")
        return { "data" => [] }
      end

      records = scope.is_a?(City) ? City.where(id: scope.id) : scope

      if min_population.present? && records.is_a?(ActiveRecord::Relation)
        records = records.where("population >= ?", min_population.to_i)
      end

      if records.is_a?(ActiveRecord::Relation) && records.count > 1
        records = apply_smart_sorting(records, sort_by)
        records = records.limit(5)
      end

      data = records.map { |c| city_payload(c) }
      Rails.logger.info("[UrbanAssist::CitiesTool] #{data.size} ville(s)")
      { "data" => data }
    end

    private

    def resolve_scope(zone_type, zone_name)
      case zone_type
      when "commune"
        return nil if zone_name.blank?

        z = zone_name.to_s.strip
        like = "%#{ActiveRecord::Base.sanitize_sql_like(z.downcase)}%"
        City.where("unaccent(lower(nom_com)) = unaccent(lower(?))", z).first ||
          City.where("unaccent(lower(nom_com)) LIKE unaccent(lower(?))", like).first
      when "department", "departement"
        return nil if zone_name.blank?

        code = department_code_for(zone_name)
        rel = City.where(dep: code).order(Arel.sql("RANDOM()")).limit(15)
        rel = City.where("unaccent(lower(nom_dep)) = unaccent(lower(?))", zone_name.to_s.strip).order(Arel.sql("RANDOM()")).limit(15) if rel.none?
        rel
      when "region"
        return nil if zone_name.blank?

        z = zone_name.to_s.strip
        City.where("unaccent(lower(nom_reg)) = unaccent(lower(?))", z)
            .order(Arel.sql("RANDOM()"))
            .limit(15)
      when "national"
        City.order(Arel.sql("RANDOM()")).limit(15)
      else
        nil
      end
    end

    def department_code_for(zone_name)
      normalized = normalize_department_slug(zone_name)
      DEPARTMENT_MAPPING[normalized] || zone_name.to_s.strip.upcase
    end

    def normalize_department_slug(name)
      return "" if name.blank?

      name.to_s.downcase.strip.gsub(/[àáâãäå]/, "a")
          .gsub(/[èéêë]/, "e")
          .gsub(/[ìíîï]/, "i")
          .gsub(/[òóôõö]/, "o")
          .gsub(/[ùúûü]/, "u")
          .gsub("ç", "c")
          .tr(" ", "-")
    end

    def city_payload(c)
      # Clés en chaînes : cohérent avec le parsing côté SendMessage et les réponses JSON.
      {
        "id" => c.id,
        "name" => c.nom_com,
        "insee_code" => c.insee,
        "department" => c.dep,
        "department_name" => c.nom_dep,
        "region" => c.nom_reg,
        "avg_price_sqm" => c.avg_price_sqm&.round,
        "median_price_sqm" => c.median_price_sqm&.round,
        "total_transactions" => c.total_transactions,
        "transactions_last_year" => c.transactions_last_year,
        "price_evolution_1y" => c.price_evolution_1y&.round(2),
        "price_evolution_3y" => c.price_evolution_3y&.round(2),
        "avg_rent_sqm" => c.avg_rent_sqm&.round(2),
        "rent_quality" => c.rent_quality&.round(2),
        "nb_obs_commune" => c.nb_obs_commune&.round,
        "population" => c.population,
        "population_density" => c.population_density&.round(2)
      }
    end

    def apply_smart_sorting(records, sort_by)
      case sort_by
      when "price_asc"
        records.order(median_price_sqm: :asc)
      when "price_desc"
        records.order(median_price_sqm: :desc)
      when "transactions"
        records.order(transactions_last_year: :desc)
      when "evolution"
        records.order(price_evolution_1y: :desc)
      else
        records.where.not(transactions_last_year: nil)
               .order(transactions_last_year: :desc)
               .order(price_evolution_1y: :desc)
      end
    end
  end
end
