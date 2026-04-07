import { Controller } from "@hotwired/stimulus"

// Ce controller Stimulus gère le toggle entre le mode affichage et le mode édition inline du profil.
//
// Stimulus fonctionne via des "targets" (éléments HTML marqués data-profile-target="...")
// et des "actions" (événements marqués data-action="...->profile#méthode").
// Cela évite de manipuler le DOM avec querySelector — Stimulus s'en charge.
export default class extends Controller {
  // On déclare les deux zones qu'on veut afficher/masquer alternativement
  static targets = ["displayMode", "editMode"]

  // Appelée quand l'utilisateur clique sur "Modifier" ou "Annuler"
  toggleEdit() {
    // classList.toggle("d-none") ajoute la classe si elle est absente, la retire si elle est présente
    this.displayModeTarget.classList.toggle("d-none")
    this.editModeTarget.classList.toggle("d-none")
  }
}
