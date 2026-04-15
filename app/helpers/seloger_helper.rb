# frozen_string_literal: true

# Helper Rails : module de méthodes disponibles automatiquement dans toutes les vues.
# On isole la logique de construction d'URL SeLoger ici pour ne pas polluer le partial.
#
# Un helper est préférable à du code inline dans la vue quand la logique dépasse
# une simple interpolation de variable.
module SelogerHelper
  # URL fixe de la page d'accueil SeLoger.
  # On centralise la constante ici pour pouvoir la modifier en un seul endroit
  # si l'URL venait à changer.
  SELOGER_HOME_URL = "https://www.seloger.com/"

  # Retourne l'URL de la page d'accueil SeLoger.
  # L'argument `city` est conservé pour ne pas casser les appels existants
  # dans les vues, mais il n'est plus utilisé dans le calcul.
  def seloger_url(city)
    SELOGER_HOME_URL
  end
end
