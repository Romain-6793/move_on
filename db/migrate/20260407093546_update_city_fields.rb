class UpdateCityFields < ActiveRecord::Migration[7.1]
  def change
    change_table :cities do |t|
      # Supprimer les anciennes colonnes
      t.remove :city_name, :latitude, :longitude, :real_estate_link,
              :real_estate_score, :nearest_big_city_score, :job_market_score,
              :transport_network_score, :activities_score, :living_cost_score,
              :cultural_heritage_score, :education_score, :sunshine_score,
              :outdoor_living_score, :entertainment_score, :health_score,
              :commercial_life_score

      # Ajouter les nouvelles colonnes
      t.string :depcom, null: false
      t.string :nom_com, null: false
      t.float :latitude, null: false
      t.float :longitude, null: false

      t.string :posi_geo
      t.string :cv
      t.string :nom_cv
      t.string :dep
      t.string :nom_dep
      t.string :reg
      t.string :nom_reg
      t.string :libgeo

      t.float :APL2023
      t.integer :code_qual

      t.float :avg_price_sqm
      t.float :median_price_sqm
      t.integer :total_transactions
      t.integer :transactions_last_year

      t.float :taux_chomage
      t.integer :population
      t.float :population_density

      t.integer :count_coll
      t.integer :count_ecol
      t.integer :count_lyce

      t.float :BUS_valeur
      t.float :BUS_vale_1
      t.float :TRAIN_valeur
      t.float :TRAIN_val_1
      t.float :METRO_vale
      t.float :METRO_va_1
      t.float :TRAM_valeur
      t.float :TRAM_val_1

      t.string :real_estate_link

      t.float :real_estate_score
      t.float :nearest_big_city_score
      t.float :job_market_score
      t.float :transport_network_score
      t.float :activities_score
      t.float :living_cost_score
      t.float :cultural_heritage_score
      t.float :education_score
      t.float :sunshine_score
      t.float :outdoor_living_score
      t.float :entertainment_score
      t.float :health_score
      t.float :commercial_life_score
    end
  end
end
