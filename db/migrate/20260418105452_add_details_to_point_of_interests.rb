class AddDetailsToPointOfInterests < ActiveRecord::Migration[7.1]
  def change
    add_column :point_of_interests, :iris_code, :string
    add_column :point_of_interests, :postal_code, :string
  end
end
