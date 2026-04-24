# frozen_string_literal: true

require 'csv'

# Seeds idempotents : on détruit d'abord pour éviter les doublons à chaque rails db:seed.
puts "🌱 Nettoyage des données existantes..."
PointOfInterest.destroy_all
City.destroy_all

# ── Import des communes depuis BD_MOVE_ON_V4.csv ────────────────────────────
puts "📊 Import des communes depuis BD_MOVE_ON_20260417.csv..."

csv_file = Rails.root.join('db', 'BD_MOVE_ON_20260417.csv')

# Fonction pour corriger l'encodage des caractères (UTF-8 mal interprété comme Latin-1)
def fix_encoding(text)
  return nil if text.nil? || text.empty?
  return text unless text.is_a?(String)

  begin
    text.encode('latin-1').force_encoding('utf-8')
  rescue EncodingError
    text
  end
end

# Fonction pour convertir en float (gère les virgules)
def parse_float(value)
  return nil if value.nil? || value.empty?
  value.to_s.gsub(',', '.').to_f
end

# Fonction pour convertir en integer
def parse_int(value)
  return nil if value.nil? || value.empty?
  value.to_i
end

batch_size = 5000  # Augmenté pour maximiser la performance
cities_batch = []
count = 0
errors = 0
start_time = Time.now

CSV.foreach(csv_file, headers: true, encoding: 'UTF-8') do |row|
  begin
    cities_batch << {
      # Identifiants
      insee: row['insee'],
      code_posta: row['code_posta'],
      nom_com: fix_encoding(row['nom_com']),

      # Géographie
      cv: row['cv'],
      nom_cv: fix_encoding(row['nom_cv']),
      dep: row['dep'],
      nom_dep: fix_encoding(row['nom_dep']),
      reg: row['reg'],
      nom_reg: fix_encoding(row['nom_reg']),
      libgeo: fix_encoding(row['libgeo']),
      paysage: row['paysage'],
      latitude: parse_float(row['latitude']),
      longitude: parse_float(row['longitude']),
      latitude_centre: parse_float(row['latitude_centre']),
      longitude_centre: parse_float(row['longitude_centre']),

      # Démographie
      population: parse_int(row['population']),
      chom_24: parse_float(row['chom_24']),
      taille_unite_urbaine: parse_int(row['taille_unite_urbaine']),

      # Santé
      APL2023: parse_float(row['APL2023']),
      code_qual: parse_int(row['code_qual']),

      # Éducation
      count_ecol: parse_int(row['count_ecol']),
      count_coll: parse_int(row['count_coll']),
      count_lyce: parse_int(row['count_lyce']),
      nb_creche: parse_int(row['nb_creche']),

      # Économie
      rev_median: parse_int(row['rev_median']),

      # Équipements
      nb_comm: parse_int(row['nb_comm']),
      nb_cultu: parse_int(row['nb_cultu']),
      nb_com_ali: parse_int(row['nb_com_ali']),
      nb_gd_surf: parse_int(row['nb_gd_surf']),
      nb_loisirs: parse_int(row['nb_loisirs']),
      nb_sport: parse_int(row['nb_sport']),
      sport_ext_nombre: parse_int(row['sport_ext_Nombre']),

      # Transports
      BUS_valeur: parse_float(row['BUS_valeur']),
      BUS_val_1: parse_float(row['BUS_val_1']),
      TRAIN_valeur: parse_float(row['TRAIN_valeur']),
      TRAIN_val_1: parse_float(row['TRAIN_val_1']),
      METRO_valeur: parse_float(row['METRO_valeur']),
      METRO_val_1: parse_float(row['METRO_val_1']),
      TRAM_valeur: parse_float(row['TRAM_valeur']),
      TRAM_val_1: parse_float(row['TRAM_val_1']),

      # Pluviométrie
      moy_cumul: parse_int(row['moy_cumul_']),
      moy_nb_jou: parse_int(row['moy_nb_jou']),

      # Vie grand air
      eq_gd_air: parse_int(row['eq_gd_air']),

      # Immobilier
      avg_price_sqm: parse_float(row['avg_price_sqm']),
      median_price_sqm: parse_float(row['median_price_sqm']),
      total_transactions: parse_int(row['total_transactions']),
      transactions_last_year: parse_int(row['transactions_last_year']),
      price_evolution_1y: parse_float(row['price_evolution_1y']),
      price_evolution_3y: parse_float(row['price_evolution_3y']),
      avg_rent_sqm: parse_float(row['avg_rent_sqm']),
      rent_quality: parse_float(row['rent_quality']),
      nb_obs_commune: parse_float(row['nb_obs_commune']),

      # Liens
      url_wikipedia: fix_encoding(row['url_wikipedia']),
      url_villedereve: fix_encoding(row['url_villedereve']),

      # 8 scores pré-calculés (0-100)
      first_deg_score: parse_float(row['score_1deg']),
      second_deg_score: parse_float(row['score_2nddeg']),
      transport_network_score: parse_float(row['score_transp']),
      health_score: parse_float(row['score_sante']),
      commercial_life_score: parse_float(row['score_economique']),
      leisures_sports_score: parse_float(row['score_sport_loisirs']),
      cultural_heritage_score: parse_float(row['score_culture']),
      real_estate_score: parse_float(row['score_immo']),
      outdoor_living_score: parse_float(row['score_grand_air']),
      sunshine_score: parse_float(row['score_pluviometrie']),
      created_at: Time.current,
      updated_at: Time.current
    }

    # Insertion par batch
    if cities_batch.size >= batch_size
      City.insert_all(cities_batch)
      count += cities_batch.size
      cities_batch = []
      
      elapsed = Time.now - start_time
      rate = count / elapsed
      print "\r✓ #{count} communes importées (#{rate.round(0)} communes/sec)..."
    end
  rescue => e
    errors += 1
    puts "\n⚠️  Erreur pour #{row['nom_com']} (#{row['insee']}): #{e.message}"
  end
end

# Insertion du dernier batch
if cities_batch.any?
  City.insert_all(cities_batch)
  count += cities_batch.size
end

elapsed = Time.now - start_time
puts "\n\n✅ Seeds terminées : #{City.count} communes importées (#{errors} erreurs) en #{elapsed.round(1)}s (#{(count / elapsed).round(0)} communes/sec)"

# Normalisation des kinds de POI : le CSV BPE24 utilise des libellés français longs,
# mais le reste de l'app (map_controller.js, MapsController) attend des identifiants
# courts en anglais pour les couleurs et les filtres de recherche.
# Ce mapping doit être mis à jour si de nouveaux types sont importés.
POI_KIND_NORMALIZATION = {
POI_KIND_NORMALIZATION = {
  "Equipements culturels et socioculturels" => "culture",
  "Equipements sportifs"                   => "sport",
  "Equipements de loisirs"                 => "sport"
  # Ajouter ici les autres types au fur et à mesure de leur import :
  # "Equipements de santé"   => "health",
  # "Equipements de transport" => "transport",
  # "Equipements d'éducation" => "education",
  # "Equipements commerciaux" => "commerce",
  # "Equipements de nature"  => "nature"
}.freeze

puts "📍 Import des Points d'Intérêt (POI)..."
print "❓ Souhaitez-vous importer les Points d'Intérêt (POI_VF.csv) ? Cela peut prendre du temps. (y/n) : "
reponse = STDIN.gets.chomp.downcase
if reponse != 'y' && reponse != 'o'
  puts "🚫 Import annulé par l'utilisateur."
else
  puts "🚀 Lancement de l'import optimisé..."
  
  # Cache des cities
  cities_cache = City.all.each_with_object({}) do |city, hash|
    clean_insee = city.insee.to_s.strip.rjust(5, '0')
    hash[clean_insee] = city.id
  end

  # Utilisation du fichier local uniquement
  poi_file = Rails.root.join('db', 'POI_VF.csv')
  
  unless File.exist?(poi_file)
    abort("� Fichier POI_VF.csv introuvable dans db/. Veuillez le placer dans le dossier db/ avant de lancer la seed.")
  end
  
  puts "📂 Utilisation du fichier local : #{poi_file}"
  batch_size = 5000  # Insère 5000 POI à la fois pour maximiser la performance
  poi_batch = []
  poi_count = 0
  poi_errors = 0
  
  start_time = Time.now

  CSV.foreach(poi_file, headers: true, col_sep: ';', encoding: 'bom|utf-8') do |row|
    begin
      raw_insee = row['#Code_commune_INSEE'] || row.to_h.values.last
      insee_csv = raw_insee.to_s.strip.rjust(5, '0')
      city_id = cities_cache[insee_csv]

      if city_id
        poi_batch << {
          city_id:     city_id,
          name:        row['NOMRS'] || "Sans nom",
          latitude:    row['LATITUDE'].to_s.gsub(',', '.').to_f,
          longitude:   row['LONGITUDE'].to_s.gsub(',', '.').to_f,
          postal_code: row['CODPOS'],
          category:    row['BPE24_varmod.LIB_MOD'],
          kind:        POI_KIND_NORMALIZATION.fetch(row['BPE24_varmod.LIB_MOD.1'], row['BPE24_varmod.LIB_MOD.1']),
          public:      true,
          created_at:  Time.current,
          updated_at:  Time.current
        }
        
        # Insertion par batch pour performance maximale
        if poi_batch.size >= batch_size
          PointOfInterest.insert_all(poi_batch)
          poi_count += poi_batch.size
          poi_batch = []
          
          elapsed = Time.now - start_time
          rate = poi_count / elapsed
          print "\r✓ #{poi_count} POI importés (#{rate.round(0)} POI/sec)..."
        end
      else
        poi_errors += 1
      end
    rescue => e
      puts "\n❌ Erreur système : #{e.message}" if poi_errors < 5
      poi_errors += 1
    end
  end

  # Insertion du dernier batch
  if poi_batch.any?
    PointOfInterest.insert_all(poi_batch)
    poi_count += poi_batch.size
  end

  elapsed = Time.now - start_time
  puts "\n\n✅ Résultat : #{poi_count} créés / #{poi_errors} échoués en #{elapsed.round(1)}s (#{(poi_count / elapsed).round(0)} POI/sec)"
end
