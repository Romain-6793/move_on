class AddFieldsToResearches < ActiveRecord::Migration[7.1]
  def change
    change_table :researches do |t|
      # --- Renommages ---
      t.rename :nearest_big_city, :near_big_city if column_exists?(:researches, :nearest_big_city)
    
      # --- Ajouts des anciennes colonnes ---
      
      t.string :chosen_nearest_big_city
      t.string :education_1
      t.string :education_2
      t.string :education_3
      t.string :education_4
      t.string :education_5
    end
  end
end
