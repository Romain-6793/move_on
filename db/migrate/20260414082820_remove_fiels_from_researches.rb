class RemoveFielsFromResearches < ActiveRecord::Migration[7.1]
  def change
    remove_column :researches, :education_1
    remove_column :researches, :education_2
    remove_column :researches, :education_3
    remove_column :researches, :education_4
    remove_column :researches, :education_5
    remove_column :researches, :activity_1
    remove_column :researches, :activity_2
    remove_column :researches, :activity_3
  end
end
