import { Controller } from "@hotwired/stimulus"

// Ce controller gère la carte Mapbox et l'affichage des données via des "layers".
//
// Pourquoi des layers plutôt que des markers individuels ?
// Avec des centaines ou milliers de points, les markers DOM (HTMLElement) saturent le navigateur.
// Les layers Mapbox sont dessinés en WebGL : ils restent fluides même avec 10 000 points.
// Le clustering (regroupement automatique de points proches) est géré nativement par Mapbox.
export default class extends Controller {
  static values = {
    token:   String,
    lat:     { type: Number, default: 46.6034 },
    lng:     { type: Number, default: 1.8883  },
    zoom:    { type: Number, default: 5       },
    dataUrl: String // URL de l'endpoint GeoJSON (passée via data-map-data-url-value)
  }

  // ── Couleurs par kind de POI — cohérentes avec la palette Move On ──────────
  // On définit les couleurs ici pour les réutiliser dans la légende ET dans les layers.
  static POI_COLORS = {
    sport:      "#7CB342", // --green-primary
    culture:    "#4FC3F7", // --blue-primary
    nature:     "#558B2F", // --green-dark
    commerce:   "#FFCA28", // --yellow-accent
    transport:  "#0288D1", // --blue-dark
    education:  "#8D6E63", // --brown-primary
    health:     "#2E9EAD"  // --blue-teal
  }

  connect() {
    if (!this.tokenValue) {
      console.error("[MapController] Token Mapbox manquant — vérifiez MAPBOX_API_KEY.")
      return
    }

    mapboxgl.accessToken = this.tokenValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style:     "mapbox://styles/mapbox/outdoors-v12",
      center:    [this.lngValue, this.latValue],
      zoom:      this.zoomValue
    })

    this.map.addControl(new mapboxgl.NavigationControl(), "top-right")

    // GeolocateControl : le navigateur demande la permission si nécessaire.
    this.geolocate = new mapboxgl.GeolocateControl({
      positionOptions:  { enableHighAccuracy: true },
      trackUserLocation: true,
      showUserHeading:   true
    })
    this.map.addControl(this.geolocate, "top-right")

    // On attend que la carte soit chargée AVANT d'ajouter les sources et layers.
    // Sinon Mapbox lèverait une erreur ("style not loaded").
    this.map.on("load", () => {
      this.geolocate.trigger() // déclenche la géolocalisation automatiquement
      this.loadMapData()
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
      id:     "cities-circles",
      type:   "circle",
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
          0,  "#e74c3c",
          5,  "#FFCA28",
          10, "#7CB342"
        ],
        "circle-opacity":      0.85,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#FFFFFF"
      }
    })

    // Layer étiquettes — nom de la ville, visible à partir du zoom 7
    this.map.addLayer({
      id:     "cities-labels",
      type:   "symbol",
      source: "cities-source",
      minzoom: 7, // n'apparaît qu'en zoomant pour ne pas surcharger la vue nationale
      layout: {
        "text-field":  ["get", "city_name"],
        "text-font":   ["Open Sans Semibold", "Arial Unicode MS Bold"],
        "text-size":   13,
        "text-offset": [0, 1.5] // décale le texte sous le cercle
      },
      paint: {
        "text-color":       "#1E2A38",
        "text-halo-color":  "#FFFFFF",
        "text-halo-width":  1.5
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
      type:           "geojson",
      data:           geojson,
      cluster:        true,      // active le clustering
      clusterMaxZoom: 13,        // au-delà de ce zoom, les clusters éclatent en points individuels
      clusterRadius:  50         // rayon en pixels dans lequel les points sont regroupés
    })

    // ── Cercles de clusters ──────────────────────────────────────────────────
    // Taille et couleur varient selon le nombre de points dans le cluster
    this.map.addLayer({
      id:     "pois-clusters",
      type:   "circle",
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
      id:     "pois-cluster-count",
      type:   "symbol",
      source: "pois-source",
      filter: ["has", "point_count"],
      layout: {
        "text-field": ["get", "point_count_abbreviated"],
        "text-font":  ["Open Sans Bold", "Arial Unicode MS Bold"],
        "text-size":  13
      },
      paint: {
        "text-color": "#1E2A38"
      }
    })

    // ── Points individuels (hors cluster) ───────────────────────────────────
    // Colorés par kind grâce à une expression match Mapbox
    this.map.addLayer({
      id:     "pois-unclustered",
      type:   "circle",
      source: "pois-source",
      filter: ["!", ["has", "point_count"]], // exclut les clusters
      paint: {
        "circle-radius": 7,
        // match compare la propriété "kind" à une liste de cas, avec un fallback gris
        "circle-color": [
          "match", ["get", "kind"],
          "sport",     "#7CB342",
          "culture",   "#4FC3F7",
          "nature",    "#558B2F",
          "commerce",  "#FFCA28",
          "transport", "#0288D1",
          "education", "#8D6E63",
          "health",    "#2E9EAD",
          "#757575" // fallback gris si kind inconnu
        ],
        "circle-stroke-width": 1.5,
        "circle-stroke-color": "#FFFFFF"
      }
    })

    // Clic sur un cluster → zoom pour l'éclater
    this.map.on("click", "pois-clusters", (e) => {
      const features   = this.map.queryRenderedFeatures(e.point, { layers: ["pois-clusters"] })
      const clusterId  = features[0].properties.cluster_id
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

    this.map.on("mouseenter", "pois-clusters",    () => { this.map.getCanvas().style.cursor = "pointer" })
    this.map.on("mouseleave", "pois-clusters",    () => { this.map.getCanvas().style.cursor = "" })
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
      sport: "#7CB342", culture: "#4FC3F7", nature: "#558B2F",
      commerce: "#FFCA28", transport: "#0288D1", education: "#8D6E63", health: "#2E9EAD"
    }
    const color     = colors[props.kind] || "#757575"
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
