class AddRegionToResearches < ActiveRecord::Migration[7.1]
  def change
    add_column :researches, :region, :string
  end
end
