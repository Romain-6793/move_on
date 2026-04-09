class CreateGuestSearches < ActiveRecord::Migration[7.1]
  def change
    create_table :guest_searches do |t|
      t.string :research_name
      t.boolean :coast
      t.boolean :mountain
      t.integer :density
      t.boolean :no_filters
      t.integer :real_estate, default: 0
      t.integer :near_big_city, default: 0
      t.integer :job_market, default: 0
      t.integer :transport_network, default: 0
      t.integer :activities, default: 0
      t.integer :living_cost, default: 0
      t.integer :cultural_heritage, default: 0
      t.integer :education, default: 0
      t.integer :sunshine, default: 0
      t.integer :outdoor_living, default: 0
      t.integer :entertainment, default: 0
      t.integer :health, default: 0
      t.integer :commercial_life, default: 0
      t.string :activity_1
      t.string :activity_2
      t.string :activity_3
      t.string :chosen_nearest_big_city
      t.string :education_1
      t.string :education_2
      t.string :education_3
      t.string :education_4
      t.string :education_5
      t.timestamps
    end
  end
end
