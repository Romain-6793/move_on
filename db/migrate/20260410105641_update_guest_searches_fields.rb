class UpdateGuestSearchesFields < ActiveRecord::Migration[7.1]
  def change
    change_table :guest_searches do |t|
      t.integer :leisures_and_sports, default: 0
    end
  end
end
