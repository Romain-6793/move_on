class RemoveFieldsFromResearchesV2 < ActiveRecord::Migration[7.1]
  def change
    remove_column :researches, :leisure_levels
  end
end
