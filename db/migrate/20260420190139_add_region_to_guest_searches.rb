class AddRegionToGuestSearches < ActiveRecord::Migration[7.1]
  def change
    add_column :guest_searches, :region, :string
  end
end
