module ApplicationHelper
  # Descriptions des critères de recherche — source de vérité unique.
  #
  # Pourquoi un helper plutôt qu'un hash répété dans chaque vue ?
  #   → DRY : une seule source à maintenir si les textes évoluent.
  #   → Réutilisation : appelé dans _research.html.erb, dans le wizard
  #     (search_steps & guest_search_steps) et dans le récap.
  #
  # La clé du hash correspond exactement au nom du champ en base (snake_case),
  # ce qui permet un accès direct par `criteria_descriptions[criterion[:key]]`.
  CRITERIA_DESCRIPTIONS = {
    'real_estate' => "Score basé sur le prix moyen au m² et le dynamisme du marché local. " \
                     "Plus le prix est accessible et le marché actif, plus la note est élevée.",
    'transport_network' => "Score calculé à partir de la densité de transports en commun " \
                           "(gares, arrêts de bus, tramways) référencés dans les données OpenStreetMap.",
    'health' => "Score basé sur la présence de professionnels de santé, hôpitaux, (données APL/data.gouv) " \
                "pharmacies et établissements médicaux dans la commune.",
    'commercial_life' => "Score reflétant la vitalité commerciale : nombre de commerces " \
                         "de proximité, marchés, boutiques et services référencés.",
    'cultural_heritage' => "Score basé sur les lieux culturels (musées, théâtres, cinémas) " \
                           "et le patrimoine historique recensé dans la commune.",
    'leisures_and_sports' => "Score basé sur les équipements sportifs, parcs, salles de sport " \
                             "et lieux de loisirs recensés dans la commune.",
    'outdoor_living' => "Score reflétant la qualité de vie au grand air : espaces verts, " \
                        "proximité de la nature, sentiers de randonnée.",
    'sunshine' => "Score basé sur le nombre de jours de pluie annuels moyens
                  de la commune (données météo).",
    'job_market' => "Score basé sur le différentiel de la ville ayant le plus faible taux de chômage avec 
                     celle ayant le plus fort taux de chômage (donnée INSEE 2024)",            
    'near_big_city' => "Score basé sur la taille de l'unité urbaine de la ville. À partir d'une taille de 6
                       (donnée INSEE) on considère que la ville est inclue dans l'aire d'une métropole",
    'education' => "Score calculé à partir du nombre d'établissements scolaires disponibles " \
                   "pour les niveaux que vous avez sélectionnés (crèches, écoles, collèges, lycées)."
  }.freeze

  # Retourne la description d'un critère donné, ou une chaîne vide si clé inconnue.
  # Accepte aussi bien un Symbol qu'une String pour plus de souplesse dans les vues.
  def criterion_description(key)
    CRITERIA_DESCRIPTIONS[key.to_s] || ''
  end

  # Rendu markdown pour les réponses du chatbot (Redcarpet + filtrage HTML).
  def markdown(text)
    return "" if text.blank?

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank", noopener: true, noreferrer: true }
    }
    extensions = {
      autolink: true,
      superscript: true,
      fenced_code_blocks: true
    }
    renderer = Redcarpet::Render::HTML.new(options)
    markdown_engine = Redcarpet::Markdown.new(renderer, extensions)
    markdown_engine.render(text).html_safe
  end
end
