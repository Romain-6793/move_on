class RemoveFieldFromGuestSearchesV2 < ActiveRecord::Migration[7.1]
  def change
    remove_column :guest_searches, :leisure_levels
  end
end
