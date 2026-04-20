# frozen_string_literal: true

# Index B-tree sur les colonnes filtrées par UrbanAssist::CitiesTool (dep, noms, insee)
# pour réduire les séquentiels sur la table cities.
class AddUrbanAssistCityLookupIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :cities, :dep, algorithm: :concurrently, if_not_exists: true
    add_index :cities, :nom_dep, algorithm: :concurrently, if_not_exists: true
    add_index :cities, :nom_reg, algorithm: :concurrently, if_not_exists: true
    add_index :cities, :insee, algorithm: :concurrently, if_not_exists: true
  end
end
