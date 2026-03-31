class CreatePointOfInterests < ActiveRecord::Migration[7.1]
  def change
    create_table :point_of_interests do |t|
      t.references :city, null: false, foreign_key: true
      t.string :name
      t.float :latitude
      t.float :longitude
      t.string :kind
      t.boolean :public, default: true
      t.string :category

      t.timestamps
    end
  end
end
