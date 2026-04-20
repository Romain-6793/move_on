// Contrôleur Stimulus pour l'étape 1 du wizard (détails).
//
// Responsabilités :
//   - Mettre à jour le texte de la valeur du slider de population
//   - Synchroniser les champs cachés coast / mountain / no_filters
//     en fonction du radio button sélectionné

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Cibles Stimulus : éléments du DOM que ce contrôleur surveille
  static targets = [
    "populationDisplay", // texte qui affiche la valeur courante du slider
    "coastField",        // champ caché research[coast]
    "mountainField",     // champ caché research[mountain]
    "noFiltersField"     // champ caché research[no_filters]
  ]

  // ─── Cycle de vie ────────────────────────────────────────────────────────

  // Initialise le slider au chargement pour que l'affichage soit correct
  // même si l'utilisateur revient sur l'étape sans avoir bougé le slider.
  connect() {
    const slider = this.element.querySelector('.wizard-slider')
    if (slider && this.hasPopulationDisplayTarget) {
      const value = parseInt(slider.value, 10) || 0
      const label = value === 0
        ? 'Toutes tailles'
        : value.toLocaleString('fr-FR') + '\u202fhab.'
      this.populationDisplayTarget.textContent = label
    }
  }

  // ─── Slider de population ────────────────────────────────────────────────

  // Déclenché sur l'événement "input" du slider (data-action="input->wizard-details#updatePopulation")
  updatePopulation(event) {
    const value = parseInt(event.currentTarget.value, 10)

    // Si la valeur est 0 → "Toutes tailles" (pas de filtre de population)
    // Sinon → valeur formatée en français avec espace fine insécable (\u202f) comme séparateur de milliers
    const label = value === 0
      ? 'Toutes tailles'
      : value.toLocaleString('fr-FR') + '\u202fhab.'

    this.populationDisplayTarget.textContent = label
  }

  // ─── Filtre géographique ──────────────────────────────────────────────────

  // Synchronise les trois champs cachés avec le radio button sélectionné.
  // Déclenché sur "change" des radio buttons (data-action="change->wizard-details#updateGeoFilter")
  updateGeoFilter(event) {
    const value = event.currentTarget.value

    // Un seul champ vaut '1', les deux autres sont remis à '0'
    this.coastFieldTarget.value      = value === 'coast'      ? '1' : '0'
    this.mountainFieldTarget.value   = value === 'mountain'   ? '1' : '0'
    this.noFiltersFieldTarget.value  = value === 'no_filters' ? '1' : '0'
  }
}
