class UpdateCitiesFieldsV5 < ActiveRecord::Migration[7.1]
  def change
    change_table :cities do |t|
      # --- Suppressions des anciennes colonnes ---
      remove_columns :cities,
        :population_density,
        :real_estate_link,
        if_exists: true

      # --- Ajout des nouvelles colonnes ---
      t.float    :latitude_centre
      t.float    :longitude_centre
      t.integer  :taille_unite_urbaine
      t.integer  :moy_cumul
      t.integer  :moy_nb_jou
      t.integer  :sport_ext_nombre
      t.integer  :rev_median
      t.integer  :eq_gd_air
      t.string   :url_wikipedia
      t.string   :url_villedereve
    end
  end
end
