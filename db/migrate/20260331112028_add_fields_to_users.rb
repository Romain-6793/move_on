class AddFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :firstname, :string
    add_column :users, :lastname, :string
    add_column :users, :date_of_birth, :datetime
    add_column :users, :situation, :string
    add_column :users, :single, :boolean
  end
end
