# frozen_string_literal: true

# Extension PostgreSQL utilisée par UrbanAssist::CitiesTool pour des recherches
# insensibles aux accents sur nom_com, nom_dep, nom_reg (équivalent ILIKE + unaccent).
class EnableUnaccentExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension "unaccent"
  end
end
