# frozen_string_literal: true

# Migration réversible (change) : Rails sait annuler un add_column automatiquement.
# On ajoute image_url en string nullable : nil signifie "image non encore récupérée".
class AddImageUrlToCities < ActiveRecord::Migration[7.1]
  def change
    add_column :cities, :image_url, :string
  end
end
