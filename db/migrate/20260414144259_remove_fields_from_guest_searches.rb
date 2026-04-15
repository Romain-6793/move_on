class RemoveFieldsFromGuestSearches < ActiveRecord::Migration[7.1]
  def change
    remove_column :guest_searches, :education_1
    remove_column :guest_searches, :education_2
    remove_column :guest_searches, :education_3
    remove_column :guest_searches, :education_4
    remove_column :guest_searches, :education_5
    remove_column :guest_searches, :activity_1
    remove_column :guest_searches, :activity_2
    remove_column :guest_searches, :activity_3
  end
end
