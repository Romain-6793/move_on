# frozen_string_literal: true

# Migration de normalisation des kinds de POI.
#
# Problème : le script d'import (seeds.rb) stocke dans la colonne `kind` la valeur
# brute du champ BPE24_varmod.LIB_MOD.1, qui est une catégorie française longue
# (ex: "Equipements culturels et socioculturels").
#
# Le reste du code (map_controller.js, MapsController::VALID_POI_KINDS) attend
# des identifiants courts en anglais ("sport", "culture", "health"…), cohérents
# avec la palette de couleurs et les filtres de recherche.
#
# Cette migration remplace les valeurs françaises par leurs équivalents normalisés.
# Elle est réversible : up/down explicites pour pouvoir revenir en arrière si besoin.
class NormalizePoiKinds < ActiveRecord::Migration[7.1]
  # Correspondance kind CSV brut → kind normalisé Move On.
  # Mettre à jour si de nouveaux types de POI sont importés.
  NORMALIZATION = {
    "Equipements culturels et socioculturels" => "culture",
    "Equipements de loisirs"                 => "loisir",
    "Equipements sportifs"                   => "sport"
  }.freeze

  def up
    NORMALIZATION.each do |french_kind, normalized_kind|
      # execute SQL directement : plus efficace qu'une boucle Ruby sur des milliers de lignes.
      # Le placeholder ? prévient toute injection SQL.
      execute(
        PointOfInterest.sanitize_sql_array(
          ["UPDATE point_of_interests SET kind = ? WHERE kind = ?", normalized_kind, french_kind]
        )
      )
    end

    say "Normalisation terminée : #{PointOfInterest.distinct.pluck(:kind).inspect}"
  end

  def down
    # On inverse le mapping pour permettre un rollback propre
    NORMALIZATION.each do |french_kind, normalized_kind|
      execute(
        PointOfInterest.sanitize_sql_array(
          ["UPDATE point_of_interests SET kind = ? WHERE kind = ?", french_kind, normalized_kind]
        )
      )
    end
  end
end
