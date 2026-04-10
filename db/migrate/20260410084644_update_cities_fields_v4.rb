class UpdateCitiesFieldsV4 < ActiveRecord::Migration[7.1]
  def change
    change_table :cities do |t|
      t.float :first_deg_score
      t.float :second_deg_score
      t.string :code_posta
      t.float :nb_obs_commune
      t.float :avg_rent_sqm
      t.float :rent_quality
    end
  end
end
