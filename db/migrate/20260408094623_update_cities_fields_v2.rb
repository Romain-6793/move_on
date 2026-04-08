class UpdateCitiesFieldsV2 < ActiveRecord::Migration[7.1]
  def change
    change_table :cities do |t|
      # --- Renommages ---
      t.rename :depcom, :insee if column_exists?(:cities, :depcom)

      # --- Suppressions des anciennes colonnes ---
      remove_columns :cities,
        :posi_geo,
        :APL2023, :code_qual,
        :avg_price_sqm, :median_price_sqm,
        :total_transactions, :transactions_last_year,
        :taux_chomage, :population, :population_density,
        :count_coll, :count_ecol, :count_lyce,
        :BUS_valeur, :BUS_vale_1,
        :TRAIN_valeur, :TRAIN_val_1,
        :METRO_vale, :METRO_va_1,
        :TRAM_valeur, :TRAM_val_1,
        :real_estate_link,
        :real_estate_score, :nearest_big_city_score,
        :job_market_score, :transport_network_score,
        :activities_score, :living_cost_score,
        :cultural_heritage_score, :education_score,
        :sunshine_score, :outdoor_living_score,
        :entertainment_score, :health_score,
        :commercial_life_score,
        if_exists: true

      # --- Ajout des nouvelles colonnes ---
      t.string  :paysage

      t.float   :APL2023
      t.integer :code_qual

      t.float   :avg_price_sqm
      t.float   :median_price_sqm
      t.integer :total_transactions
      t.integer :transactions_last_year

      t.float   :chom_24
      t.integer :population
      t.float   :population_density

      t.integer :count_coll
      t.integer :count_ecol
      t.integer :count_lyce

      t.integer :nb_comm
      t.integer :nb_cultu
      t.integer :nb_com_ali
      t.integer :nb_gd_surf
      t.integer :nb_loisirs
      t.integer :nb_sport
      t.integer :nb_creche

      t.float   :BUS_valeur
      t.float   :BUS_val_1

      t.float   :TRAIN_valeur
      t.float   :TRAIN_val_1

      t.float   :METRO_valeur
      t.float   :METRO_val_1

      t.float   :TRAM_valeur
      t.float   :TRAM_val_1

      t.string  :real_estate_link

      t.float   :real_estate_score
      t.float   :nearest_big_city_score
      t.float   :job_market_score
      t.float   :transport_network_score
      t.float   :activities_score
      t.float   :living_cost_score
      t.float   :cultural_heritage_score
      t.float   :education_score
      t.float   :sunshine_score
      t.float   :outdoor_living_score
      t.float   :entertainment_score
      t.float   :health_score
      t.float   :commercial_life_score
    end
  end
end
