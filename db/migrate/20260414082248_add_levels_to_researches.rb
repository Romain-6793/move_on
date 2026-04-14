class AddLevelsToResearches < ActiveRecord::Migration[7.1]
  def change
    add_column :researches, :education_levels, :string, array: true, default: []
    add_column :researches, :leisure_levels, :string, array: true, default: []
  end
end
