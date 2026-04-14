class AddLevelsToGuestSearches < ActiveRecord::Migration[7.1]
  def change
    add_column :guest_searches, :education_levels, :string, array: true, default: []
    add_column :guest_searches, :leisure_levels, :string, array: true, default: []
  end
end
