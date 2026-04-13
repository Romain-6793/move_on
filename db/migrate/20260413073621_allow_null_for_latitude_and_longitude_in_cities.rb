class AllowNullForLatitudeAndLongitudeInCities < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cities, :latitude, true
    change_column_null :cities, :longitude, true
  end
end
