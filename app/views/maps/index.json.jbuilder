# frozen_string_literal: true

# Ce fichier construit la réponse GeoJSON consommée par Mapbox.
# jbuilder génère du JSON avec une DSL Ruby — plus lisible que .to_json sur des hashes.
#
# On retourne deux FeatureCollections séparées dans un seul objet JSON :
# - "cities"  : une feature par ville (cercle proportionnel au score composite)
# - "pois"    : une feature par POI (point coloré par kind, clusterisé côté Mapbox)
#
# GeoJSON spec : https://geojson.org/
# Un Feature = { type: "Feature", geometry: { type: "Point", coordinates: [lng, lat] }, properties: {} }
# ATTENTION Mapbox : l'ordre des coordonnées est [LONGITUDE, LATITUDE] (inverse de l'intuition).

json.cities do
  json.type "FeatureCollection"
  json.features @cities do |city|
    json.type "Feature"
    json.geometry do
      json.type  "Point"
      json.coordinates [city.longitude, city.latitude]  # [lng, lat] — ordre GeoJSON
    end
    json.properties do
      json.id                      city.id
      json.city_name               city.city_name
      json.real_estate_score       city.real_estate_score
      json.job_market_score        city.job_market_score
      json.transport_network_score city.transport_network_score
      json.activities_score        city.activities_score
      json.living_cost_score       city.living_cost_score
      json.education_score         city.education_score
      json.health_score            city.health_score
      json.sunshine_score          city.sunshine_score
      json.outdoor_living_score    city.outdoor_living_score
      json.entertainment_score     city.entertainment_score
      json.cultural_heritage_score city.cultural_heritage_score
      json.commercial_life_score   city.commercial_life_score
      # Score composite = moyenne de tous les scores disponibles.
      # compact_blank retire les nil avant le calcul (sécurité si un score manque).
      scores = [
        city.real_estate_score, city.job_market_score, city.transport_network_score,
        city.activities_score, city.living_cost_score, city.education_score,
        city.health_score, city.sunshine_score, city.outdoor_living_score,
        city.entertainment_score, city.cultural_heritage_score, city.commercial_life_score
      ].compact
      json.composite_score scores.any? ? (scores.sum / scores.size).round(1) : 0
    end
  end
end

json.pois do
  json.type "FeatureCollection"
  # flat_map récupère tous les POIs de toutes les villes en une seule liste
  # grâce au includes(:point_of_interests) dans le controller, pas de N+1 ici.
  json.features @cities.flat_map(&:point_of_interests) do |poi|
    json.type "Feature"
    json.geometry do
      json.type  "Point"
      json.coordinates [poi.longitude, poi.latitude]
    end
    json.properties do
      json.id        poi.id
      json.name      poi.name
      json.kind      poi.kind
      json.category  poi.category
      json.public    poi.public
      json.city_name poi.city.city_name
    end
  end
end
