# frozen_string_literal: true

# Service object : calcule un score transports 0–100 et un détail pédagogique pour une commune.
#
# Pourquoi un service plutôt que du code dans le modèle City ?
# Même logique que RealEstateScoreCalculator : la normalisation dépend du *jeu* de communes
# (min / max sur le scope affiché), pas seulement d'une ligne en base — on garde le modèle léger.
#
# Méthode : indice brut = (TRAIN_valeur × 4) + (METRO_valeur × 3) + (TRAM_valeur × 2) + (BUS_valeur × 1).
# Les *_valeur sont déjà normalisées par 1000 habitants (cf. README / import CSV).
# Les poids reflètent l'importance relative des modes (capacité, attractivité du réseau lourd).
#
# Normalisation : min–max sur le scope, score élevé = meilleure offre relative (comme l'immobilier).
# Le README mentionne aussi des rangs centiles côté pipeline données ; l'API carte utilise ici
# min–max pour rester cohérent avec RealEstateScoreCalculator et explicite mathématiquement.
  class TransportNetworkScoreCalculator
    WEIGHTS = {
      train: 4,
      metro: 3,
      tram: 2,
      bus: 1
    }.freeze

    def initialize(scope)
      @cities = Array(scope)
      @indices = @cities.map { |city| self.class.weighted_index(city) }
      @min = @indices.min
      @max = @indices.max
    end

    # Calcule les résultats pour toutes les villes du scope : une seule passe min/max (performant pour la carte).
    def results_by_city_id
      @cities.index_by(&:id).transform_values { |city| for_city(city) }
    end

    def for_city(city)
      index = self.class.weighted_index(city)
      {
        final_score: normalize_index(index).round(2),
        weighted_index: index.round(4),
        components: weighted_components(city),
        caption: caption
      }
    end

    def self.weighted_index(city)
      train = city.TRAIN_valeur.to_f
      metro = city.METRO_valeur.to_f
      tram = city.TRAM_valeur.to_f
      bus = city.BUS_valeur.to_f

      (train * WEIGHTS[:train]) + (metro * WEIGHTS[:metro]) + (tram * WEIGHTS[:tram]) + (bus * WEIGHTS[:bus])
    end

    private

    attr_reader :cities, :indices, :min, :max

    def weighted_components(city)
      {
        train: (city.TRAIN_valeur.to_f * WEIGHTS[:train]).round(4),
        metro: (city.METRO_valeur.to_f * WEIGHTS[:metro]).round(4),
        tram: (city.TRAM_valeur.to_f * WEIGHTS[:tram]).round(4),
        bus: (city.BUS_valeur.to_f * WEIGHTS[:bus]).round(4)
      }
    end

    # Plus l'indice pondéré est élevé, meilleur est le score (plus d'arrêts / gares par habitant, modes lourds valorisés).
    def normalize_index(index)
      return 50.0 if max.nil? || min.nil? || max == min

      100.0 * (index - min) / (max - min)
    end

    # Texte court pour l'UI : rappelle la formule sans jargon technique.
    def caption
      @caption ||= "Comparé aux autres villes affichées : train ×#{WEIGHTS[:train]}, métro ×#{WEIGHTS[:metro]}, " \
        "tram ×#{WEIGHTS[:tram]}, bus ×#{WEIGHTS[:bus]} (stations / 1000 hab.), puis normalisation."
    end
  end
