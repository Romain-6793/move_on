# frozen_string_literal: true

require "net/http"
require "json"

# Service Object : récupère une photo représentative d'une ville via l'API Wikipedia.
#
# Pourquoi Wikipedia plutôt qu'Unsplash ?
#   → Aucune clé API requise : l'API REST Wikimedia est publique et sans authentification.
#   → Les images sont issues de Wikimedia Commons (licences libres Creative Commons).
#   → Chaque article Wikipedia d'une ville française contient généralement
#     une photo principale très représentative (panorama, centre-ville, monument).
#
# Endpoint utilisé :
#   GET https://fr.wikipedia.org/api/rest_v1/page/summary/{titre}
#   → Retourne un résumé de l'article avec thumbnail et originalimage.
#
# Stratégie de cache : l'URL est persistée dans cities.image_url.
# Une fois remplie, on ne rappelle plus jamais l'API pour cette ville.
class CityImageFetcherService
  # On préfère originalimage (pleine résolution) à thumbnail (320px) pour la qualité.
  # Si originalimage est absent (rare), on se replie sur thumbnail.
  WIKIPEDIA_API_BASE = "https://fr.wikipedia.org/api/rest_v1/page/summary"

  # L'API Wikimedia exige un User-Agent identifiable (bonne pratique documentée).
  # Format recommandé : "NomApp/version (contact)"
  USER_AGENT = "MoveOn/1.0 (contact@moveon.fr)"

  def initialize(city)
    @city = city
  end

  # Point d'entrée du service.
  # Retourne l'URL de l'image (string) ou nil si introuvable.
  def call
    # Court-circuit : si l'image est déjà en base, aucun appel réseau.
    return @city.image_url if @city.image_url.present?

    image_url = fetch_from_wikipedia
    # update_column bypasse les callbacks ActiveRecord (validations, timestamps) :
    # on ne fait qu'écrire une URL, inutile de déclencher toute la chaîne.
    @city.update_column(:image_url, image_url) if image_url.present?

    image_url
  end

  private

  def fetch_from_wikipedia
    uri      = build_uri
    response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT })

    # On ne traite que les réponses 200 OK.
    return nil unless response.is_a?(Net::HTTPSuccess)

    parse_image_url(response.body)
  rescue StandardError => e
    # rescue StandardError (jamais Exception) : on intercepte les erreurs réseau,
    # de parsing JSON, etc., sans masquer les erreurs système (SignalException…).
    Rails.logger.error("[CityImageFetcherService] Erreur Wikipedia pour '#{@city.nom_com}' : #{e.message}")
    nil
  end

  # Construit l'URI en encodant le nom de la ville pour l'URL.
  # URI.encode_www_form_component gère les accents, espaces et tirets :
  #   "Aix-en-Provence" → "Aix-en-Provence" (tirets conservés, accents encodés)
  #   "Châlons-en-Champagne" → "Ch%C3%A2lons-en-Champagne"
  def build_uri
    # Wikipedia accepte le nom de la commune tel quel (sans slug) — les majuscules
    # et accents sont conservés car c'est le titre exact de l'article Wikipedia.
    encoded_name = URI.encode_www_form_component(@city.nom_com)
    URI("#{WIKIPEDIA_API_BASE}/#{encoded_name}")
  end

  # Extrait l'URL de l'image depuis la réponse JSON Wikipedia.
  # Structure de la réponse :
  #   {
  #     "originalimage": { "source": "https://upload.wikimedia.org/...", ... },
  #     "thumbnail":     { "source": "https://upload.wikimedia.org/...", ... }
  #   }
  def parse_image_url(body)
    data = JSON.parse(body)
    # On préfère originalimage (meilleure qualité), avec thumbnail en fallback.
    # dig navigue dans le hash sans lever d'exception si une clé est absente.
    data.dig("originalimage", "source") || data.dig("thumbnail", "source")
  rescue JSON::ParserError => e
    Rails.logger.error("[CityImageFetcherService] Réponse JSON invalide pour '#{@city.nom_com}' : #{e.message}")
    nil
  end
end
