import { Controller } from "@hotwired/stimulus"

// Stimulus controller dédié à la city_card (carte d'une ville dans les résultats).
//
// Rôle actuel : gérer l'accordéon "En savoir plus" qui déplie la liste des liens
// vers des sources d'infos externes (Wikipedia, Ville de Rêve).
//
// Pourquoi un contrôleur dédié plutôt que d'étendre research_form_controller ?
// - Principe de responsabilité unique : research_form gère le formulaire de
//   recherche, pas les résultats qui en découlent.
// - La city-card est réutilisée sur plusieurs pages (résultats researches,
//   résultats guest_searches). Un contrôleur qui lui est propre évite tout
//   couplage avec le wizard de création.
export default class extends Controller {
  // Les targets déclarent les éléments du DOM que le contrôleur manipule.
  // Ils sont repérés dans la vue via `data-city-card-target="..."`.
  static targets = ["accordion", "toggleButton"]

  // Bascule l'ouverture / fermeture de l'accordéon.
  // On manipule l'attribut HTML natif `hidden` (équivaut à display:none)
  // plutôt qu'une classe CSS : c'est plus sémantique et interprété nativement
  // par les lecteurs d'écran (accessibilité).
  toggleAccordion(event) {
    // preventDefault au cas où le bouton serait un <button> dans un <form> :
    // évite toute soumission intempestive du formulaire parent.
    event.preventDefault()

    const isOpen = !this.accordionTarget.hidden
    this.accordionTarget.hidden = isOpen

    // Le libellé + la flèche indiquent visuellement l'état courant du panneau.
    this.toggleButtonTarget.textContent = isOpen ? "En savoir plus ▾" : "Réduire ▴"
  }
}
