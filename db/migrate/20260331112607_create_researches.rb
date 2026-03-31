class CreateResearches < ActiveRecord::Migration[7.1]
  def change
    create_table :researches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :research_name
      t.boolean :coast
      t.boolean :mountain
      t.integer :density, default: 2000
      t.boolean :no_filters
      t.integer :real_estate, default: 0
      t.integer :nearest_big_city, default: 0
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

      t.timestamps
    end
  end
end
