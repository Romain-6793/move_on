# frozen_string_literal: true

# Migration réversible (change) : Rails peut automatiquement annuler cette migration avec db:rollback.
class AddRelocationProjectToUsers < ActiveRecord::Migration[7.1]
  def change
    # On ajoute un champ texte libre pour que l'utilisateur décrive son projet de relocation.
    # :text est préféré à :string car le contenu peut être long (plusieurs phrases).
    add_column :users, :relocation_project, :text
  end
end
