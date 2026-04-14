# frozen_string_literal: true

# Helper Rails : module de méthodes disponibles automatiquement dans toutes les vues.
# On isole la logique de construction d'URL SeLoger ici pour ne pas polluer le partial.
#
# Un helper est préférable à du code inline dans la vue quand la logique dépasse
# une simple interpolation de variable (ici : slugification + concaténation d'URL).
module SelogerHelper
  # Retourne l'URL de recherche SeLoger pour une ville et un type de transaction.
  #
  # Paramètres :
  #   city  — instance de City (doit répondre à #nom_com)
  #   type  — :achat (défaut) ou :locations
  #
  # Exemples :
  #   seloger_url(city)             # => "https://www.seloger.com/immobilier/achat/immo-lyon/"
  #   seloger_url(city, :locations) # => "https://www.seloger.com/immobilier/locations/immo-bordeaux/"
  #
  # `parameterize` est une méthode ActiveSupport qui convertit une chaîne en slug URL :
  #   "Saint-Étienne" => "saint-etienne"
  #   "Aix-en-Provence" => "aix-en-provence"
  def seloger_url(city, type = :achat)
    slug = city.nom_com.parameterize
    "https://www.seloger.com/immobilier/#{type}/immo-#{slug}/"
  end
end
