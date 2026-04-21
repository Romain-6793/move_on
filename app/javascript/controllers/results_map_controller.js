import { Controller } from "@hotwired/stimulus"

// Ce controller gère la carte dédiée à l'affichage des 5 villes de résultats.
//
// Différence avec map_controller.js (carte générale) :
// - Reçoit les données directement en inline JSON (pas de fetch vers /maps.json)
// - Crée des marqueurs HTML personnalisés (rang + nom de ville) au lieu de layers WebGL
// - Ajuste automatiquement le zoom pour englober les 5 villes (fitBounds)
//
// Pourquoi des marqueurs DOM plutôt que des layers WebGL ?
// Avec seulement 5 points, le surcoût DOM est négligeable, et les markers HTML
// offrent un contrôle CSS complet (forme, couleur, animation, responsive).

// Couleurs par rang — du meilleur (vert foncé #1) au 5ème (rouge doux #5).
// Constante module-level pour pouvoir la référencer dans les méthodes de la classe.
// Reprend exactement la palette Move On : --green-dark, --blue-teal, --blue-dark, --orange-warm, --red-soft.
const RANK_COLORS = ["#558B2F", "#2E9EAD", "#0288D1", "#FFB74D", "#E57373"]

export default class extends Controller {
  static values = {
    token:    String,
    // Les 5 villes avec id, nom_com, nom_dep, nom_reg, latitude, longitude, rank
    cities:   Array,
    // Les kinds de POI sélectionnés comme essentiels — pour construire les liens
    // vers map#show avec le bon filtre ?kinds=transport,health,...
    poiKinds: Array
  }

  connect() {
    if (!this.tokenValue) {
      console.error("[ResultsMapController] Token Mapbox manquant — vérifiez MAPBOX_API_KEY.")
      return
    }

    mapboxgl.accessToken = this.tokenValue

    // Centré sur la France entière par défaut ; fitBounds corrigera le zoom
    // automatiquement une fois les marqueurs placés.
    this.map = new mapboxgl.Map({
      container: this.element,
      style:     "mapbox://styles/mapbox/outdoors-v12",
      center:    [1.8883, 46.6034],
      zoom:      5
    })

    this.map.addControl(new mapboxgl.NavigationControl(), "top-right")

    // On attend que la carte soit rendue avant d'ajouter les marqueurs.
    this.map.on("load", () => {
      this.addResultMarkers()
    })
  }

  // ── Marqueurs personnalisés pour les 5 villes ────────────────────────────
  addResultMarkers() {
    // LngLatBounds sera étendu pour chaque ville, puis passé à fitBounds
    // pour que la carte zoome automatiquement sur la bonne région.
    const bounds = new mapboxgl.LngLatBounds()

    this.citiesValue.forEach((city) => {
      const markerEl = this.createMarkerElement(city)

      // mapboxgl.Marker avec un element DOM custom.
      // anchor: "bottom" → la pointe de l'épingle touche exactement les coordonnées.
      new mapboxgl.Marker({ element: markerEl, anchor: "bottom" })
        .setLngLat([city.longitude, city.latitude])
        .setPopup(
          new mapboxgl.Popup({ offset: 30, closeButton: false })
            .setHTML(this.cityPopupHtml(city))
        )
        .addTo(this.map)

      bounds.extend([city.longitude, city.latitude])
    })

    // fitBounds ajuste zoom et centre pour voir tous les marqueurs.
    // padding: 90px évite que les marqueurs collent aux bords de la carte.
    // maxZoom: 9 empêche un zoom trop fort si deux villes sont proches.
    if (!bounds.isEmpty()) {
      this.map.fitBounds(bounds, { padding: 90, maxZoom: 9, duration: 800 })
    }
  }

  // Crée l'élément DOM du marqueur : une épingle colorée + un label avec le nom.
  // La couleur est injectée en style inline pour pouvoir différencier les rangs.
  createMarkerElement(city) {
    const rank  = city.rank
    const color = RANK_COLORS[rank - 1] || "#757575"

    const el = document.createElement("div")
    // La classe CSS rank-N permet d'appliquer des styles supplémentaires par rang si besoin
    el.className = `results-marker results-marker--rank-${rank}`

    el.innerHTML = `
      <div class="results-marker__pin" style="background:${color}">
        <span class="results-marker__rank">#${rank}</span>
      </div>
      <span class="results-marker__label">${city.nom_com}</span>
    `
    return el
  }

  // Construit le HTML du popup affiché au clic sur un marqueur.
  // Le lien "Voir les points d'intérêt" transporte les kinds sélectionnés
  // pour que la page show filtre les POIs automatiquement.
  cityPopupHtml(city) {
    const rank  = city.rank
    const color = RANK_COLORS[rank - 1] || "#757575"

    // Construction du lien vers maps#show avec le filtre kinds si des critères essentiels existent
    const kinds = this.poiKindsValue
    const href  = kinds.length
      ? `/maps/${city.id}?kinds=${kinds.join(",")}`
      : `/maps/${city.id}`

    // Localisation (département · région) — affichée seulement si disponible
    const locParts = [city.nom_dep, city.nom_reg].filter(Boolean)
    const location = locParts.length
      ? `<p class="map-popup__location">${locParts.join(" · ")}</p>`
      : ""

    return `
      <div class="map-popup map-popup--result">
        <div class="map-popup__rank-badge" style="background:${color}">#${rank}</div>
        <h3 class="map-popup__title">${city.nom_com}</h3>
        ${location}
        <a href="${href}" class="map-popup__cta">
          Voir les points d'intérêt →
        </a>
      </div>
    `
  }

  disconnect() {
    // Libère la mémoire WebGL — indispensable avec Turbo (le controller se déconnecte
    // lors des navigations et un nouveau est créé à chaque visite de la page).
    if (this.map) this.map.remove()
  }
}
