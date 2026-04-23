import { Controller } from "@hotwired/stimulus"

// Ce controller gère la carte Mapbox et l'affichage des données via des "layers".
//
// Pourquoi des layers plutôt que des markers individuels ?
// Avec des centaines ou milliers de points, les markers DOM (HTMLElement) saturent le navigateur.
// Les layers Mapbox sont dessinés en WebGL : ils restent fluides même avec 10 000 points.
// Le clustering (regroupement automatique de points proches) est géré nativement par Mapbox.

// Couleurs par rang dans le classement des 5 meilleures villes.
// Dupliqué depuis results_map_controller.js (RANK_COLORS) pour que le marqueur
// de la vue show (une seule ville) reprenne exactement la même apparence que
// sur la carte des 5 résultats. Si la palette évolue, penser à mettre à jour
// les deux fichiers (pas de dépendance directe entre controllers Stimulus).
const RANK_COLORS = ["#558B2F", "#2E9EAD", "#0288D1", "#FFB74D", "#E57373"]

export default class extends Controller {
  static values = {
    token: String,
    lat: { type: Number, default: 46.6034 },
    lng: { type: Number, default: 1.8883 },
    zoom: { type: Number, default: 5 },
    dataUrl: String, // URL de l'endpoint GeoJSON (passée via data-map-data-url-value)
    geolocate: Boolean,
    // cityName permet d'afficher le nom dans le popup du marqueur de ville unique (vue show)
    cityName: String,
    // rank : position de la ville dans le classement des 5 meilleures (1..5).
    // 0 = pas de rang connu → on retombe sur un marqueur Mapbox par défaut.
    // Utilisé pour afficher le même marqueur (pastille couleur + chiffre)
    // que sur la carte des 5 résultats (voir results_map_controller.js).
    rank: { type: Number, default: 0 },
    // pois : features GeoJSON pré-filtrés passés en inline par maps#show.
    // Quand ce tableau est non vide, on n'appelle PAS loadMapData() (pas de fetch vers /maps.json)
    // et on affiche uniquement ces POIs — vue centrée sur une ville spécifique.
    pois: { type: Array, default: [] },
    // essentialKinds : les 3 critères essentiels du user (ex: ["transport", "health", "culture"]).
    // Chaque kind donne lieu à une pastille colorée autour du centre-ville (voir addEssentialDots).
    // Permet au user de voir immédiatement ses critères sur la carte, même si la BD
    // ne contient pas (encore) de POIs pour tous les kinds.
    essentialKinds: { type: Array, default: [] },
    // otherCities : tableau des 4 AUTRES villes du top 5 (la ville courante
    // est déjà affichée par addCityMarker). Chaque élément contient id,
    // nom_com, nom_dep, nom_reg, latitude, longitude et rank (1..5).
    // Les marqueurs sont placés à leur position réelle : ils restent hors du
    // cadre au zoom initial (13) et deviennent visibles dès que l'utilisateur
    // dézoome suffisamment pour englober la région.
    otherCities: { type: Array, default: [] },
    // poiKinds : critères essentiels sélectionnés — propagés dans les liens
    // des popups des autres villes pour conserver le filtre ?kinds=…
    poiKinds: { type: Array, default: [] },
    // researchId : identifiant de la recherche utilisateur (connecté uniquement),
    // transmis dans les liens des popups pour que le prochain maps#show puisse
    // recharger le contexte et, à son tour, afficher les 4 autres villes.
    // Vide pour les visiteurs (le fallback se fait via session[:guest_search_id]).
    researchId: { type: String, default: "" },
    // pinUrl : URL de l'image custom utilisée comme marqueur fallback (rank inconnu).
    // Passée depuis la vue ERB via asset_path pour bénéficier du fingerprinting Assets.
    pinUrl: { type: String, default: "" }
  }

  // ── Labels FR par kind — affichés au survol des pastilles essentielles ────
  // Cohérents avec maps/show.html.erb (même table). Centralisés ici pour éviter
  // la duplication côté JS.
  static POI_LABELS = {
    sport: "Sports et loisirs",
    culture: "Culture et patrimoine",
    nature: "Nature",
    commerce: "Vie commerciale",
    transport: "Transports",
    education: "Éducation",
    health: "Santé"
  }

  // ── Couleurs par kind de POI — cohérentes avec la légende de maps/show.html.erb ──
  // Les 3 kinds réellement affichés (sport, loisir, culture) reprennent exactement
  // les couleurs de la légende pour que marqueurs et légende soient identiques.
  // Attention : le kind en base est "loisir" (sans 's') — voir migration NormalizePoiKinds.
  static POI_COLORS = {
    sport: "#EF5350",   // rouge — Équipements sportifs
    loisir: "#E57373",  // rouge clair — Équipements de loisirs
    culture: "#9575CD", // violet — Équipements culturels et socioculturels
    commerce: "#FFCA28", // --yellow-accent
    transport: "#0288D1", // --blue-dark
    education: "#8D6E63", // --brown-primary
    health: "#2E9EAD"   // --blue-teal
  }

  connect() {
    if (!this.tokenValue) {
      console.error("[MapController] Token Mapbox manquant — vérifiez MAPBOX_API_KEY.")
      return
    }

    mapboxgl.accessToken = this.tokenValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/outdoors-v12",
      center: [this.lngValue, this.latValue],
      zoom: this.zoomValue
    })

    this.map.addControl(new mapboxgl.NavigationControl(), "top-right")

    // GeolocateControl : le navigateur demande la permission si nécessaire.
    if (this.geolocateValue) {
      this.geolocate = new mapboxgl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: true,
        showUserHeading: true
      })
      this.map.addControl(this.geolocate, "top-right")
    }

    // On attend que la carte soit chargée AVANT d'ajouter les sources et layers.
    // Sinon Mapbox lèverait une erreur ("style not loaded").
    this.map.on("load", () => {
      // this.geolocate n'est défini que si geolocateValue est true (voir ci-dessus).
      // Appeler .trigger() sans ce garde levait une TypeError qui bloquait tout le callback.
      if (this.geolocateValue) this.geolocate.trigger()

      // Si une ville précise est ciblée (vue show), on pose un marqueur à ses coordonnées.
      if (this.cityNameValue) this.addCityMarker()

      // Marqueurs des 4 autres villes du top 5 — identiques à ceux de la carte
      // des résultats (pastille colorée + chiffre). Hors du viewport au zoom
      // initial, ils réapparaissent naturellement quand le user dézoome.
      if (this.otherCitiesValue.length > 0) this.addOtherRankedMarkers()

      // Pastilles des critères essentiels — matérialisent les 3 critères "must-have"
      // du user directement sur la carte, quel que soit l'état des données POI.
      if (this.essentialKindsValue.length > 0) this.addEssentialDots()

      if (this.poisValue.length > 0) {
        // Vue show : les POIs ont été pré-filtrés et sérialisés côté serveur (maps#show).
        // On les affiche directement sans appel réseau supplémentaire.
        // On construit une FeatureCollection GeoJSON valide à partir du tableau de features.
        this.addPoisLayer({ type: "FeatureCollection", features: this.poisValue })
      } else if (this.dataUrlValue) {
        // Vue index : chargement de l'ensemble des villes + POIs depuis l'endpoint /maps.json.
        this.loadMapData()
      }
      // Si aucune des deux conditions n'est vraie (pas de POIs ET pas de dataUrl),
      // la carte affiche uniquement le marqueur de la ville sans couche de données.
    })
  }

  // ── Chargement des données GeoJSON depuis le serveur ──────────────────────
  async loadMapData() {
    try {
      // fetch() appelle notre endpoint /maps.json en AJAX.
      // On ajoute le header Accept pour que Rails réponde bien en JSON.
      const response = await fetch(this.dataUrlValue, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) throw new Error(`Erreur HTTP ${response.status}`)

      const data = await response.json()

      this.addCitiesLayer(data.cities)
      this.addPoisLayer(data.pois)
    } catch (error) {
      console.error("[MapController] Impossible de charger les données :", error)
    }
  }

  // ── Marqueur de la ville ciblée (vue show uniquement) ────────────────────
  // Contrairement aux layers WebGL, un Marker Mapbox est un élément DOM :
  // c'est acceptable ici car il n'y a qu'un seul point à afficher.
  //
  // Si un rang (1..5) est fourni, on crée un marqueur HTML custom identique à
  // celui de la carte des 5 résultats (pastille colorée + chiffre + label).
  // Sinon, on retombe sur le marqueur Mapbox par défaut — cohérence visuelle
  // maximale quand on navigue depuis la city_card vers la vue ville-unique.
  addCityMarker() {
    const popup = new mapboxgl.Popup({ offset: 30, closeButton: false })
      .setHTML(`<strong class="map-popup__title">${this.cityNameValue}</strong>`)

    if (this.rankValue > 0) {
      // Marker avec élément DOM personnalisé.
      // anchor: "bottom" → la pointe de l'épingle pointe exactement sur la ville.
      const markerEl = this.createRankMarkerElement(this.rankValue, this.cityNameValue)
      new mapboxgl.Marker({ element: markerEl, anchor: "bottom" })
        .setLngLat([this.lngValue, this.latValue])
        .setPopup(popup)
        .addTo(this.map)
    } else if (this.pinUrlValue) {
      // Fallback avec image custom : un élément DOM dont le background est le pin Move On.
      // anchor: "bottom" → la pointe de l'image touche exactement les coordonnées.
      const markerEl = document.createElement("div")
      markerEl.style.cssText = [
        "width: 40px",
        "height: 40px",
        `background-image: url('${this.pinUrlValue}')`,
        "background-size: contain",
        "background-repeat: no-repeat",
        "background-position: center bottom",
        "cursor: pointer"
      ].join(";")
      new mapboxgl.Marker({ element: markerEl, anchor: "bottom" })
        .setLngLat([this.lngValue, this.latValue])
        .setPopup(popup)
        .addTo(this.map)
    } else {
      // Dernier fallback : marqueur Mapbox standard si pas d'image disponible.
      new mapboxgl.Marker({ color: "#2E9EAD" })
        .setLngLat([this.lngValue, this.latValue])
        .setPopup(popup)
        .addTo(this.map)
    }
  }

  // Construit le DOM du marqueur personnalisé. Structure et classes identiques
  // à results_map_controller.js#createMarkerElement pour que le CSS soit partagé
  // (.results-marker / .results-marker__pin / .results-marker__rank / .results-marker__label).
  createRankMarkerElement(rank, cityName) {
    const color = RANK_COLORS[rank - 1] || "#757575"

    const el = document.createElement("div")
    el.className = `results-marker results-marker--rank-${rank}`
    el.innerHTML = `
      <div class="results-marker__pin" style="background:${color}">
        <span class="results-marker__rank">${rank}</span>
      </div>
      <span class="results-marker__label">${cityName}</span>
    `
    return el
  }

  // ── Marqueurs des 4 autres villes du top 5 ────────────────────────────────
  //
  // Pourquoi cette méthode ?
  // Sur la vue show on centre la carte sur une seule ville (zoom 13), mais
  // on veut que les 4 autres villes du classement restent disponibles : dès
  // que l'utilisateur dézoome pour voir plus largement la France/la région,
  // leurs marqueurs apparaissent naturellement (Mapbox n'affiche que ce qui
  // est dans le viewport).
  //
  // Les marqueurs reprennent exactement le style de la carte des 5 résultats
  // (même pastille colorée, même chiffre, même label) pour préserver la
  // continuité visuelle — un #2 sur la carte générale reste un #2 ici.
  addOtherRankedMarkers() {
    this.otherCitiesValue.forEach((city) => {
      const el = this.createRankMarkerElement(city.rank, city.nom_com)

      // anchor: "bottom" → la pointe de l'épingle touche précisément les coordonnées.
      new mapboxgl.Marker({ element: el, anchor: "bottom" })
        .setLngLat([city.longitude, city.latitude])
        .setPopup(
          new mapboxgl.Popup({ offset: 30, closeButton: false })
            .setHTML(this.otherCityPopupHtml(city))
        )
        .addTo(this.map)
    })
  }

  // Popup identique à celle de la carte des 5 résultats : rang, nom, localisation,
  // et lien pour ouvrir la carte dédiée de cette autre ville (avec le même filtre
  // de kinds + research_id pour préserver le contexte de recherche).
  otherCityPopupHtml(city) {
    const color = RANK_COLORS[city.rank - 1] || "#757575"

    // URLSearchParams échappe automatiquement les valeurs — pas de risque
    // d'injection via kinds ou research_id.
    const params = new URLSearchParams()
    params.set("rank", city.rank)
    if (this.poiKindsValue.length) params.set("kinds", this.poiKindsValue.join(","))
    if (this.researchIdValue) params.set("research_id", this.researchIdValue)
    const href = `/maps/${city.id}?${params.toString()}`

    // Localisation optionnelle (département · région) — même rendu que
    // results_map_controller.js#cityPopupHtml pour la cohérence visuelle.
    const locParts = [city.nom_dep, city.nom_reg].filter(Boolean)
    const location = locParts.length
      ? `<p class="map-popup__location">${locParts.join(" · ")}</p>`
      : ""

    return `
      <div class="map-popup map-popup--result">
        <div class="map-popup__rank-badge" style="background:${color}">${city.rank}</div>
        <h3 class="map-popup__title">${city.nom_com}</h3>
        ${location}
        <a href="${href}" class="map-popup__cta">
          Voir les points d'intérêt →
        </a>
      </div>
    `
  }

  // ── Pastilles des critères essentiels (vue show uniquement) ───────────────
  //
  // Pourquoi cette méthode ?
  // Les POIs (voir addPoisLayer) affichent les équipements réels — mais la base
  // ne contient aujourd'hui que les kinds "culture" et "sport". Si le user a choisi
  // "santé" ou "transport" comme critère essentiel, aucun point ne s'afficherait.
  // Ces pastilles garantissent que les 3 critères essentiels sont TOUJOURS visibles
  // sur la carte, sous forme de repères colorés autour du centre-ville.
  //
  // Implémentation : des mapboxgl.Marker avec élément DOM custom. On accepte le
  // surcoût DOM car on a au plus 3 pastilles (contrairement aux layers WebGL
  // utilisés pour les POIs qui peuvent se compter en milliers).
  addEssentialDots() {
    const kinds = this.essentialKindsValue
    // Distribution en cercle autour du centre-ville : chaque kind est placé à
    // angle régulier (360° / nombre de kinds). Le rayon est petit (~0.004°)
    // pour que les pastilles restent visibles au zoom 13 sans masquer la ville.
    const radius = 0.004
    const center = { lng: this.lngValue, lat: this.latValue }

    kinds.forEach((kind, index) => {
      // -Math.PI/2 place la première pastille en haut (12h), sens horaire
      const angle = (index / kinds.length) * 2 * Math.PI - Math.PI / 2
      // Correction de la longitude par cos(lat) pour éviter que le cercle
      // soit écrasé aux latitudes élevées (projection Web Mercator).
      const lng = center.lng + (radius * Math.cos(angle)) / Math.cos(center.lat * Math.PI / 180)
      const lat = center.lat + radius * Math.sin(angle)

      const color = this.constructor.POI_COLORS[kind] || "#757575"
      const label = this.constructor.POI_LABELS[kind] || kind

      const el = document.createElement("div")
      el.className = "essential-dot"
      // title : tooltip natif du navigateur au survol — gratuit et accessible.
      el.title = label
      el.innerHTML = `
        <span class="essential-dot__circle" style="background:${color}"></span>
        <span class="essential-dot__label" style="border-color:${color}">${label}</span>
      `

      new mapboxgl.Marker({ element: el, anchor: "center" })
        .setLngLat([lng, lat])
        .addTo(this.map)
    })
  }

  // ── Layer VILLES ──────────────────────────────────────────────────────────
  // Affiche chaque ville comme un cercle dont la taille et la couleur
  // dépendent du score composite (moyenne de tous les critères).
  addCitiesLayer(geojson) {
    // addSource enregistre les données brutes — on peut y brancher plusieurs layers
    this.map.addSource("cities-source", {
      type: "geojson",
      data: geojson
    })

    // Layer cercles — taille et couleur proportionnelles au score composite
    this.map.addLayer({
      id: "cities-circles",
      type: "circle",
      source: "cities-source",
      paint: {
        // interpolate crée une interpolation linéaire entre les valeurs :
        // score 0 → rayon 8px, score 10 → rayon 24px
        "circle-radius": [
          "interpolate", ["linear"],
          ["get", "composite_score"],
          0, 8,
          10, 24
        ],
        // score 0 → rouge, score 5 → orange, score 10 → vert (code couleur intuitif)
        "circle-color": [
          "interpolate", ["linear"],
          ["get", "composite_score"],
          0, "#e74c3c",
          5, "#FFCA28",
          10, "#7CB342"
        ],
        "circle-opacity": 0.85,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#FFFFFF"
      }
    })

    // Layer étiquettes — nom de la ville, visible à partir du zoom 7
    this.map.addLayer({
      id: "cities-labels",
      type: "symbol",
      source: "cities-source",
      minzoom: 7, // n'apparaît qu'en zoomant pour ne pas surcharger la vue nationale
      layout: {
        "text-field": ["get", "city_name"],
        "text-font": ["Open Sans Semibold", "Arial Unicode MS Bold"],
        "text-size": 13,
        "text-offset": [0, 1.5] // décale le texte sous le cercle
      },
      paint: {
        "text-color": "#1E2A38",
        "text-halo-color": "#FFFFFF",
        "text-halo-width": 1.5
      }
    })

    // Popup au clic sur une ville
    this.map.on("click", "cities-circles", (e) => {
      const props = e.features[0].properties
      new mapboxgl.Popup()
        .setLngLat(e.lngLat)
        .setHTML(this.cityPopupHtml(props))
        .addTo(this.map)
    })

    // Curseur pointer au survol pour indiquer que c'est cliquable
    this.map.on("mouseenter", "cities-circles", () => {
      this.map.getCanvas().style.cursor = "pointer"
    })
    this.map.on("mouseleave", "cities-circles", () => {
      this.map.getCanvas().style.cursor = ""
    })
  }

  // ── Layer POIs (avec clustering) ──────────────────────────────────────────
  // Le clustering regroupe automatiquement les points proches en un seul cercle
  // avec le décompte. C'est géré côté Mapbox (WebGL), pas en JS — très performant.
  addPoisLayer(geojson) {
    this.map.addSource("pois-source", {
      type: "geojson",
      data: geojson,
      cluster: true,      // active le clustering
      clusterMaxZoom: 13,        // au-delà de ce zoom, les clusters éclatent en points individuels
      clusterRadius: 50         // rayon en pixels dans lequel les points sont regroupés
    })

    // ── Cercles de clusters ──────────────────────────────────────────────────
    // Taille et couleur varient selon le nombre de points dans le cluster
    this.map.addLayer({
      id: "pois-clusters",
      type: "circle",
      source: "pois-source",
      filter: ["has", "point_count"], // ne s'applique qu'aux clusters, pas aux points seuls
      paint: {
        "circle-color": [
          "step", ["get", "point_count"],
          "#B3E5FC",  // < 10 points → bleu clair
          10, "#4FC3F7", // 10-29 → bleu moyen
          30, "#0288D1"  // ≥ 30   → bleu foncé
        ],
        "circle-radius": [
          "step", ["get", "point_count"],
          20,      // < 10 points → rayon 20px
          10, 30,  // 10-29 → 30px
          30, 42   // ≥ 30  → 42px
        ],
        "circle-stroke-width": 2,
        "circle-stroke-color": "#FFFFFF"
      }
    })

    // ── Nombre de points dans chaque cluster ────────────────────────────────
    this.map.addLayer({
      id: "pois-cluster-count",
      type: "symbol",
      source: "pois-source",
      filter: ["has", "point_count"],
      layout: {
        "text-field": ["get", "point_count_abbreviated"],
        "text-font": ["Open Sans Bold", "Arial Unicode MS Bold"],
        "text-size": 13
      },
      paint: {
        "text-color": "#1E2A38"
      }
    })

    // ── Points individuels (hors cluster) ───────────────────────────────────
    // Colorés par kind grâce à une expression match Mapbox
    this.map.addLayer({
      id: "pois-unclustered",
      type: "circle",
      source: "pois-source",
      filter: ["!", ["has", "point_count"]], // exclut les clusters
      paint: {
        "circle-radius": 7,
        // match compare la propriété "kind" à une liste de cas, avec un fallback gris.
        // Les couleurs sont synchronisées avec static POI_COLORS ET la légende de maps/show.html.erb.
        "circle-color": [
          "match", ["get", "kind"],
          "sport", "#EF5350",  // rouge — Équipements sportifs
          "loisir", "#E57373",  // rouge clair — Équipements de loisirs
          "culture", "#9575CD",  // violet — Équipements culturels et socioculturels
          "commerce", "#FFCA28",
          "transport", "#0288D1",
          "education", "#8D6E63",
          "health", "#2E9EAD",
          "#757575" // fallback gris si kind inconnu
        ],
        "circle-stroke-width": 1.5,
        "circle-stroke-color": "#FFFFFF"
      }
    })

    // Clic sur un cluster → zoom pour l'éclater
    this.map.on("click", "pois-clusters", (e) => {
      const features = this.map.queryRenderedFeatures(e.point, { layers: ["pois-clusters"] })
      const clusterId = features[0].properties.cluster_id
      this.map.getSource("pois-source").getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return
        this.map.easeTo({ center: features[0].geometry.coordinates, zoom })
      })
    })

    // Clic sur un POI individuel → popup
    this.map.on("click", "pois-unclustered", (e) => {
      const props = e.features[0].properties
      new mapboxgl.Popup()
        .setLngLat(e.lngLat)
        .setHTML(this.poiPopupHtml(props))
        .addTo(this.map)
    })

    this.map.on("mouseenter", "pois-clusters", () => { this.map.getCanvas().style.cursor = "pointer" })
    this.map.on("mouseleave", "pois-clusters", () => { this.map.getCanvas().style.cursor = "" })
    this.map.on("mouseenter", "pois-unclustered", () => { this.map.getCanvas().style.cursor = "pointer" })
    this.map.on("mouseleave", "pois-unclustered", () => { this.map.getCanvas().style.cursor = "" })
  }

  // ── Templates HTML des popups ─────────────────────────────────────────────
  // On construit le HTML manuellement pour éviter toute dépendance externe.
  // Note : Mapbox échappe automatiquement les valeurs insérées via setHTML — pas de risque XSS.
  cityPopupHtml(props) {
    const score = props.composite_score
    const color = score >= 7 ? "#7CB342" : score >= 4 ? "#FFCA28" : "#e74c3c"
    return `
      <div class="map-popup map-popup--city">
        <h3 class="map-popup__title">${props.city_name}</h3>
        <p class="map-popup__score" style="color:${color}">
          Score global : <strong>${score}/10</strong>
        </p>
        <ul class="map-popup__scores">
          <li>Emploi : ${props.job_market_score}</li>
          <li>
            Transports : <strong>${props.transport_network_score}</strong>
            ${props.transport_network_caption
        ? `<div class="map-popup__hint">${props.transport_network_caption}</div>`
        : ""}
            ${props.transport_component_train != null
        ? `<div class="map-popup__breakdown">Train ×4 : ${props.transport_component_train} · Métro ×3 : ${props.transport_component_metro} · Tram ×2 : ${props.transport_component_tram} · Bus : ${props.transport_component_bus}</div>`
        : ""}
          </li>
          <li>Éducation : ${props.education_score}</li>
          <li>Santé : ${props.health_score}</li>
          <li>Soleil : ${props.sunshine_score}</li>
        </ul>
      </div>
    `
  }

  poiPopupHtml(props) {
    const colors = {
      sport: "#EF5350", culture: "#9575CD", loisir: "#E57373", nature: "#558B2F",
      commerce: "#FFCA28", transport: "#0288D1", education: "#8D6E63", health: "#2E9EAD"
    }
    const color = colors[props.kind] || "#757575"
    const publicBadge = props.public ? "Public" : "Privé"
    return `
      <div class="map-popup map-popup--poi">
        <span class="map-popup__badge" style="background:${color}">${props.kind}</span>
        <h3 class="map-popup__title">${props.name}</h3>
        <p class="map-popup__meta">${props.category} · ${publicBadge}</p>
        <p class="map-popup__city">📍 ${props.city_name}</p>
      </div>
    `
  }

  disconnect() {
    if (this.map) this.map.remove()
  }
}
