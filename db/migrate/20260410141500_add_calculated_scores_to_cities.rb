class AddCalculatedScoresToCities < ActiveRecord::Migration[7.1]
  def change
    # Retirer la contrainte NOT NULL sur latitude et longitude
    change_column_null :cities, :latitude, true
    change_column_null :cities, :longitude, true
    
    change_table :cities do |t|
      # 8 nouveaux scores pré-calculés (0-100)
      t.float :score_1deg           # Score petite enfance (écoles + crèches)
      t.float :score_2nddeg          # Score second degré (collèges + lycées)
      t.float :score_transp          # Score transports pondérés
      t.float :score_sante           # Score santé (accès médecins)
      t.float :score_economique      # Score économique (commerces)
      t.float :score_sport_loisirs   # Score sport & loisirs
      t.float :score_culture         # Score culture
      t.float :score_immo            # Score immobilier

      # Colonnes immobilières manquantes
      t.float :price_evolution_1y    # Évolution prix 1 an (%)
      t.float :price_evolution_3y    # Évolution prix 3 ans (%)
      t.float :avg_rent_sqm          # Loyer moyen au m²
      t.float :rent_quality          # Qualité du loyer
      t.float :nb_obs_commune        # Nombre d'observations

      # Colonne CSV manquante
      t.string :code_posta           # Code postal
    end
  end
end