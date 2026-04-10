# frozen_string_literal: true

require 'csv'

# Seeds idempotents : on détruit d'abord pour éviter les doublons à chaque rails db:seed.
puts "🌱 Nettoyage des données existantes..."
PointOfInterest.destroy_all
City.destroy_all

# ── Import des communes depuis BD_MOVE_ON_V4.csv ────────────────────────────
puts "📊 Import des communes depuis BD_MOVE_ON_V4.csv..."

csv_file = Rails.root.join('db', 'BD_MOVE_ON_V4.csv')
count = 0
errors = 0

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

CSV.foreach(csv_file, headers: true, encoding: 'UTF-8') do |row|
  begin
    City.create!(
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
      
      # Démographie
      population: parse_int(row['population']),
      chom_24: parse_float(row['chom_24']),
      
      # Santé
      APL2023: parse_float(row['APL2023']),
      code_qual: parse_int(row['code_qual']),
      
      # Éducation
      count_ecol: parse_int(row['count_ecol']),
      count_coll: parse_int(row['count_coll']),
      count_lyce: parse_int(row['count_lyce']),
      nb_creche: parse_int(row['nb_creche']),
      
      # Équipements
      nb_comm: parse_int(row['nb_comm']),
      nb_cultu: parse_int(row['nb_cultu']),
      nb_com_ali: parse_int(row['nb_com_ali']),
      nb_gd_surf: parse_int(row['nb_gd_surf']),
      nb_loisirs: parse_int(row['nb_loisirs']),
      nb_sport: parse_int(row['nb_sport']),
      
      # Transports
      BUS_valeur: parse_float(row['BUS_valeur']),
      BUS_val_1: parse_float(row['BUS_val_1']),
      TRAIN_valeur: parse_float(row['TRAIN_valeur']),
      TRAIN_val_1: parse_float(row['TRAIN_val_1']),
      METRO_valeur: parse_float(row['METRO_valeur']),
      METRO_val_1: parse_float(row['METRO_val_1']),
      TRAM_valeur: parse_float(row['TRAM_valeur']),
      TRAM_val_1: parse_float(row['TRAM_val_1']),
      
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
      
      # 8 scores pré-calculés (0-100)
      score_1deg: parse_float(row['score_1deg']),
      score_2nddeg: parse_float(row['score_2nddeg']),
      score_transp: parse_float(row['score_transp']),
      score_sante: parse_float(row['score_sante']),
      score_economique: parse_float(row['score_economique']),
      score_sport_loisirs: parse_float(row['score_sport_loisirs']),
      score_culture: parse_float(row['score_culture']),
      score_immo: parse_float(row['score_immo'])
    )
    
    count += 1
    print "\r  ✓ #{count} communes importées..." if count % 1000 == 0
  rescue => e
    errors += 1
    puts "\n  ⚠️  Erreur pour #{row['nom_com']} (#{row['insee']}): #{e.message}"
  end
end

puts "\n\n✅ Seeds terminées : #{City.count} communes importées (#{errors} erreurs)"
