class CreateCities < ActiveRecord::Migration[7.1]
  def change
    create_table :cities do |t|
      t.string :city_name
      t.float :latitude
      t.float :longitude
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

      t.timestamps
    end
  end
end
