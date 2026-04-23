# Move On 🏡

**Move On** est une application web Rails qui aide les particuliers à trouver la ville idéale pour s'installer en France, en fonction de leurs critères personnels (transports, santé, éducation, immobilier, cadre de vie, etc.).

🌐 **Production** : [https://www.moveonfrance.me](https://www.moveonfrance.me)

---

## Fonctionnalités

- **Wizard de recherche en 4 étapes** — critères essentiels, priorités, filtres géographiques (côte, montagne, densité, région)
- **Classement des 5 meilleures villes** — score composite calculé en SQL via `CityRankerService`
- **Carte interactive Mapbox** — affichage des villes classées, points d'intérêt (POI) filtrés par critère
- **Mode visiteur** — recherche sans inscription via `GuestSearch` (session)
- **Export PDF** — fiche de résultats téléchargeable (WickedPDF)
- **Urban Assist** — chatbot IA (RubyLLM / OpenAI) pour explorer les villes en langage naturel
- **Authentification** — Devise (inscription, connexion, reset de mot de passe)
- **Autorisations** — Pundit (chaque utilisateur n'accède qu'à ses propres données)

---

## Stack technique

| Couche | Technologie |
|---|---|
| Framework | Ruby on Rails 7.1 |
| Base de données | PostgreSQL |
| Authentification | Devise |
| Autorisations | Pundit |
| Wizard multi-étapes | Wicked |
| Carte | Mapbox GL JS v3.11 |
| Frontend | Stimulus, Turbo, Bootstrap |
| PDF | WickedPDF + wkhtmltopdf |
| IA / chatbot | RubyLLM (OpenAI) |
| Jobs asynchrones | Solid Queue |
| Recherche | pg_search |
| Stockage fichiers | Active Storage |

---

## Installation locale

### Prérequis

- Ruby 3.x
- PostgreSQL
- wkhtmltopdf (pour l'export PDF)

### Setup

```bash
bundle install
rails db:create db:migrate
rails db:seed          # optionnel — données de démonstration
rails server
```

### Variables d'environnement

Créer un fichier `.env` ou configurer les credentials Rails (`rails credentials:edit`) :

```
MAPBOX_API_KEY=pk.xxx...
OPENAI_API_KEY=sk-xxx...
```

---

## Architecture

```
app/
├── controllers/
│   ├── search_steps_controller.rb       # Wizard recherche (utilisateurs)
│   ├── guest_search_steps_controller.rb # Wizard recherche (visiteurs)
│   ├── researches_controller.rb         # Résultats, édition, export PDF
│   ├── maps_controller.rb               # Cartes Mapbox
│   ├── messages_controller.rb           # Chatbot SSE streaming
│   └── chats_controller.rb
├── models/
│   ├── city.rb                          # ~36 000 communes françaises
│   ├── research.rb                      # Recherche utilisateur
│   ├── guest_search.rb                  # Recherche visiteur (session)
│   ├── user.rb
│   └── chat.rb / message.rb
├── services/
│   ├── city_ranker_service.rb           # Score composite SQL
│   ├── city_image_fetcher_service.rb    # Images Wikipedia (avec cache)
│   └── urban_assist/
│       ├── send_message.rb              # Orchestration LLM + SSE
│       └── cities_tool.rb              # Outil RubyLLM pour le chatbot
└── policies/                            # Pundit
```

---

## Base de données — champs CSV source

La base de données est construite à partir du fichier `BD_MOVE_ON_20260415.csv`.

# fichier CSV BD_MOVE_ON_20260415.csv

## Liste des champs et description des données

### Identifiants et localisation

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **insee** | Code INSEE de la commune | "03297", "61494" |
| **code_posta** | Code postal de la commune | "3190.0", "61160.0" |
| **nom_com** | Nom de la commune | Vallon-en-Sully, Trun |
| **cv** | Code de la communauté de communes | "307", "6105" |
| **nom_cv** | Nom de la communauté de communes | Huriel, Argentan-2 |
| **dep** | Code du département | "3", "61" |
| **nom_dep** | Nom du département | Allier, Orne |
| **reg** | Code de la région | "84", "28" |
| **nom_reg** | Nom de la région | Auvergne-Rhône-Alpes, Normandie |
| **libgeo** | Libellé géographique (souvent vide) | Trun, (vide) |
| **latitude** | Latitude GPS de la Mairie de la commune | 48.851, 46.123 |
| **longitude** | Longitude GPS de la Mairie de la commune | 0.046, 2.308 |
| **latitude_centre** | Latitude GPS (géographique) du centre de la commune | 48.851, 46.123 |
| **longitude_centre** | Longitude GPS (géographique) du centre de la commune | 0.046, 2.308 |
| **taille_unite_urbaine** | Taille de l'unité urbaine (nombre d'habitants). 0 = commune rurale et 8 = métropole | "0.0", "1.0", "7.0" |

### Démographie et environnement

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **population** | Population de la commune | "1485", "1225" |
| **rev_median** | Revenu médian par commune (€/an) | "20310", "22440", "25000" |
| **chom_24** | Taux de chômage par région dernier trimestre 2024 (%) | "6.8", "7.2" |
| **paysage** | Type de paysage | "littoral", "montagne", "plaine" |
| **code_qual** | Indicateur qualité de l'air : 1=Bon, 2=Moyen, 3=Dégradé, 4=Mauvais, 5=Très mauvais, 6=Extrêmement mauvais, 0=Absent, 7=Évènement | "2", "3" |

### Santé

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **APL2023** | Indice APL (Accessibilité Potentielle Localisée) pour les médecins généralistes en 2023. Plus l'indice est élevé, meilleur est l'accès aux soins | "2.0", "3.5", "2.6" |

### Éducation et petite enfance

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **count_ecol** | Nombre d'écoles primaires | 1, 2, 1 |
| **count_coll** | Nombre de collèges | 1, 1, 0 |
| **count_lyce** | Nombre de lycées | 0, 0, 1 |
| **nb_creche** | Nombre de crèches | "0", "2", "3" |

### Transports

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **BUS_valeur** | Indicateur normalisé du réseau de bus (stations / 1000 hab.) | "0.00", "1.69", "6.45" |
| **BUS_val_1** | Nombre absolu de stations de bus | "0.00", "2.00", "9.00" |
| **TRAIN_valeur** | Indicateur normalisé du réseau ferroviaire (gares / 1000 hab.) | "0.00", "1.36", "0.24" |
| **TRAIN_val_1** | Nombre absolu de gares | "0.00", "2.00", "1.00" |
| **METRO_valeur** | Indicateur normalisé du réseau de métro (stations / 1000 hab.) | "0.00", "1.36", "0.00" |
| **METRO_val_1** | Nombre absolu de stations de métro | "0.00", "2.00", "0.00" |
| **TRAM_valeur** | Indicateur normalisé du réseau de tramway (stations / 1000 hab.) | "0.00", "0.00", "0.00" |
| **TRAM_val_1** | Nombre absolu de stations de tramway | "0.00", "0.00", "0.00" |

### Équipements et services

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **nb_comm** | Nombre d'équipements de commerce général | "15", "452" |
| **nb_com_ali** | Nombre d'équipements de commerce alimentaire | "9", "452" |
| **nb_gd_surf** | Nombre de grandes surfaces | "1", "10" |
| **nb_cultu** | Nombre d'équipements culturels | "11", "45" |
| **nb_loisirs** | Nombre d'équipements de loisirs | "49", "89" |
| **nb_sport** | Nombre d'équipements sportifs | "0", "45" |
| **eq_gd_air** | Nombre d'équipements de grand air (espaces naturels, parcs, etc.) | "0", "2", "7" |
| **sport_ext_Nombre** | Nombre de sports d'extérieur disponibles | "0", "2", "22" |

### Immobilier

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **avg_price_sqm** | Prix moyen au m² (€) | "896.91", "2149.63" |
| **median_price_sqm** | Prix médian au m² (€) | "857.72", "1198.72" |
| **total_transactions** | Nombre total de transactions immobilières en 2024| "121", "79" |
| **transactions_last_year** | Nombre de transactions sur la dernière année | "121", "79" |
| **price_evolution_1y** | Évolution 2023→2024 (%) | "-7.95", "-21.82" |
| **price_evolution_3y** | Évolution 2022→2024 (%) | "-18.83", "3.49" |
| **avg_rent_sqm** | Loyer €/m²/mois | "7.72", "8.81" |
| **rent_quality** | Qualité prédiction (R²) | "0.725", "0.784" |
| **nb_obs_commune** | Nombre d'observations pour les données immobilières | "62", "118" |

### Météorologie

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **moy_cumul_** | Moyenne du cumul de pluie par an en millimètres | "582", "757", "1187" |
| **moy_nb_jou** | Moyenne du nombre de jours de pluie par an | "99", "130", "131" |

### Métadonnées et liens

| Champ | Description | Exemple de données |
|-------|-------------|-------------------|
| **url_wikipedia** | URL de la page Wikipedia de la commune | https://fr.wikipedia.org/wiki/fr:Vallon-en-Sully |
| **url_villedereve** | URL de la fiche commune sur villedereve.fr | https://villedereve.fr/ville/03297-vallon-en-sully |

### Scores pré-calculés (0-100)

| Champ | Description | Méthode de calcul |
|-------|-------------|-------------------|
| **score_1deg** | Score accueil petite enfance | Rang centile de (count_ecol + nb_creche). Plus il y a d'équipements, meilleur est le score |
| **score_2nddeg** | Score second degré | Rang centile de (count_coll + count_lyce). Plus il y a d'équipements, meilleur est le score |
| **score_transp** | Score transports | Rang centile de la somme pondérée : (TRAIN × 4) + (METRO × 3) + (TRAM × 2) + (BUS × 1). Les poids reflètent l'importance de chaque mode de transport |
| **score_sante** | Score santé | Rang centile de l'APL2023. Plus l'accessibilité aux médecins généralistes est élevée, meilleur est le score |
| **score_economique** | Score dynamisme commercial | Rang centile de (nb_com_ali + nb_gd_surf). Plus il y a de commerces, meilleur est le score |
| **score_sport_loisirs** | Score sport & loisirs | Rang centile de (nb_sport + nb_loisirs). Plus il y a d'équipements, meilleur est le score |
| **score_culture** | Score culture | Rang centile de nb_cultu. Plus il y a d'équipements culturels, meilleur est le score |
| **score_immo** | Score immobilier | Composite de 2 indicateurs : **price_score (60%)** = normalisation min-max inversée de [(median_price_sqm × 0.7) + (avg_price_sqm × 0.3)] → prix bas = bon score ; **market_score (40%)** = normalisation min-max de [(transactions_last_year × 0.7) + (total_transactions × 0.3)] → plus de transactions = bon score. Score final = (price_score × 0.6) + (market_score × 0.4) |
| **score_grand_air** | Score grand air | Rang centile de (eq_gd_air + sport_ext_Nombre). Plus il y a d'équipements de grand air et de sports extérieurs, meilleur est le score |
| **score_pluviometrie** | Score pluviométrie | Score inversé (donc attention plus la note est basse plus il y a beaucoup de pluie et régulièrement) basé sur un composite de la pluviométrie : **cumul_norm (60%)** = normalisation min-max de moy_cumul_ ; **nb_jours_norm (40%)** = normalisation min-max de moy_nb_jou. Score final = (1 - composite) × 100 → moins de pluie = meilleur score |
