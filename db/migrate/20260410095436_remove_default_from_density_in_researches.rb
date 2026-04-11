class RemoveDefaultFromDensityInResearches < ActiveRecord::Migration[7.1]
  def change
    change_column_default :researches, :density, from: 2000, to: nil
    change_table :researches do |t|
      t.integer :leisures_and_sports, default: 0
    end
  end
end
