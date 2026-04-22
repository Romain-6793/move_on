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

  // Affiche un aperçu local de l'image sélectionnée avant l'envoi du formulaire.
  // FileReader.readAsDataURL() lit le fichier en mémoire et produit une data URL (base64)
  // que l'on injecte comme src d'une balise <img>.
  previewAvatar(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      const wrapper = document.getElementById("avatar-preview-wrapper")
      // On remplace le contenu du wrapper par une <img> avec l'aperçu
      wrapper.innerHTML = `<img src="${e.target.result}"
                                alt="Aperçu"
                                class="profile-avatar-img"
                                id="avatar-preview">`
    }
    reader.readAsDataURL(file)
  }
}
