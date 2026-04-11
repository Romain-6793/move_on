class UpdateCitiesFieldsV3 < ActiveRecord::Migration[7.1]
  def change
    change_table :cities do |t|
      t.float :price_evolution_1y
      t.float :price_evolution_3y
      t.float :leisures_sports_score
    end
  end
end
