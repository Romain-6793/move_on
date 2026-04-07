# frozen_string_literal: true

# Seeds idempotents : on détruit d'abord pour éviter les doublons à chaque rails db:seed.
# En production on utiliserait find_or_create_by! à la place.
puts "🌱 Nettoyage des données existantes..."
PointOfInterest.destroy_all
City.destroy_all

# ── Villes françaises réelles ────────────────────────────────────────────────
# On utilise des coordonnées réelles pour que la carte soit cohérente géographiquement.
# Les scores sont générés aléatoirement pour simuler la future vraie donnée.
FRENCH_CITIES = [
  { name: "Paris",             lat: 48.8566,  lng:  2.3522 },
  { name: "Marseille",         lat: 43.2965,  lng:  5.3698 },
  { name: "Lyon",              lat: 45.7640,  lng:  4.8357 },
  { name: "Toulouse",          lat: 43.6047,  lng:  1.4442 },
  { name: "Nice",              lat: 43.7102,  lng:  7.2620 },
  { name: "Nantes",            lat: 47.2184,  lng: -1.5536 },
  { name: "Strasbourg",        lat: 48.5734,  lng:  7.7521 },
  { name: "Montpellier",       lat: 43.6108,  lng:  3.8767 },
  { name: "Bordeaux",          lat: 44.8378,  lng: -0.5792 },
  { name: "Lille",             lat: 50.6292,  lng:  3.0573 },
  { name: "Rennes",            lat: 48.1173,  lng: -1.6778 },
  { name: "Reims",             lat: 49.2583,  lng:  4.0317 },
  { name: "Le Havre",          lat: 49.4938,  lng:  0.1079 },
  { name: "Saint-Étienne",     lat: 45.4397,  lng:  4.3872 },
  { name: "Toulon",            lat: 43.1242,  lng:  5.9280 },
  { name: "Grenoble",          lat: 45.1885,  lng:  5.7245 },
  { name: "Dijon",             lat: 47.3220,  lng:  5.0415 },
  { name: "Angers",            lat: 47.4784,  lng: -0.5632 },
  { name: "Nîmes",             lat: 43.8367,  lng:  4.3601 },
  { name: "Clermont-Ferrand",  lat: 45.7772,  lng:  3.0870 },
  { name: "Le Mans",           lat: 48.0061,  lng:  0.1996 },
  { name: "Aix-en-Provence",   lat: 43.5297,  lng:  5.4474 },
  { name: "Brest",             lat: 48.3904,  lng: -4.4861 },
  { name: "Limoges",           lat: 45.8336,  lng:  1.2611 },
  { name: "Tours",             lat: 47.3941,  lng:  0.6848 },
  { name: "Amiens",            lat: 49.8941,  lng:  2.2957 },
  { name: "Perpignan",         lat: 42.6987,  lng:  2.8956 },
  { name: "Metz",              lat: 49.1193,  lng:  6.1757 },
  { name: "Besançon",          lat: 47.2378,  lng:  6.0241 },
  { name: "Caen",              lat: 49.1829,  lng: -0.3707 }
].freeze

# ── Catégories de points d'intérêt ──────────────────────────────────────────
# Chaque "kind" est un type général (visible sur la légende),
# chaque "category" est un sous-type plus précis (visible dans le popup).
POI_KINDS = {
  "sport"      => %w[stade piscine salle_de_sport tennis piste_cyclable],
  "culture"    => %w[musée théâtre cinéma bibliothèque galerie_art],
  "nature"     => %w[parc forêt lac sentier_randonnée jardin_botanique],
  "commerce"   => %w[marché centre_commercial halles zone_commerciale],
  "transport"  => %w[gare aéroport station_métro arrêt_bus parking_vélos],
  "education"  => %w[université lycée école_primaire grande_école médiathèque],
  "health"     => %w[hôpital clinique pharmacie centre_médical maison_santé]
}.freeze

# ── Création des villes et de leurs POIs ────────────────────────────────────
puts "🏙️  Création de #{FRENCH_CITIES.size} villes..."

FRENCH_CITIES.each do |city_data|
  # rand(1.0..10.0).round(1) génère un float entre 1.0 et 10.0 avec 1 décimale
  city = City.create!(
    city_name:                city_data[:name],
    latitude:                 city_data[:lat],
    longitude:                city_data[:lng],
    real_estate_score:        rand(1.0..10.0).round(1),
    nearest_big_city_score:   rand(1.0..10.0).round(1),
    job_market_score:         rand(1.0..10.0).round(1),
    transport_network_score:  rand(1.0..10.0).round(1),
    activities_score:         rand(1.0..10.0).round(1),
    living_cost_score:        rand(1.0..10.0).round(1),
    cultural_heritage_score:  rand(1.0..10.0).round(1),
    education_score:          rand(1.0..10.0).round(1),
    sunshine_score:           rand(1.0..10.0).round(1),
    outdoor_living_score:     rand(1.0..10.0).round(1),
    entertainment_score:      rand(1.0..10.0).round(1),
    health_score:             rand(1.0..10.0).round(1),
    commercial_life_score:    rand(1.0..10.0).round(1)
  )

  # Chaque ville reçoit entre 5 et 12 POIs aléatoires
  rand(5..12).times do
    kind     = POI_KINDS.keys.sample
    category = POI_KINDS[kind].sample

    # On disperse les POIs dans un rayon de ~5 km autour du centre-ville
    # 0.05 degré ≈ 5 km — suffisant pour que les points soient distincts sur la carte
    lat_offset = rand(-0.05..0.05)
    lng_offset = rand(-0.05..0.05)

    PointOfInterest.create!(
      city:      city,
      name:      "#{category.capitalize.tr('_', ' ')} #{Faker::Address.street_name}",
      latitude:  city_data[:lat] + lat_offset,
      longitude: city_data[:lng] + lng_offset,
      kind:      kind,
      category:  category,
      public:    [true, true, true, false].sample # 75% publics
    )
  end

  print "  ✓ #{city_data[:name]} (#{city.point_of_interests.count} POIs)\n"
end

puts "\n✅ Seeds terminées : #{City.count} villes, #{PointOfInterest.count} points d'intérêt."
