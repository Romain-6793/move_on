import { Controller } from "@hotwired/stimulus"

// Controller Stimulus : ferme automatiquement un flash message après un court délai.
//
// Pourquoi : les messages de confirmation (sign-in, mise à jour de profil, etc.)
// n'ont pas besoin de rester longtemps à l'écran. Avant cette modification, ils
// restaient visibles jusqu'à ce que l'utilisateur clique sur la croix ou change
// de page, ce qui parasitait l'interface.
//
// Choix technique : on manipule directement les classes Bootstrap (`fade`, `show`)
// plutôt que d'appeler l'API JS `bootstrap.Alert`. Raison : via importmap,
// `bootstrap.min.js` est chargé pour ses effets de bord (il expose `window.bootstrap`)
// mais n'expose pas forcément d'exports ESM nommés, ce qui rend `import { Alert }`
// peu fiable. Retirer la classe `show` déclenche la transition CSS `fade` de
// Bootstrap (opacité → 0), puis on supprime l'élément du DOM à la fin de la
// transition — comportement visuel identique, sans dépendance à l'API JS.
//
// Utilisation (ERB) :
//   <div class="alert fade show" data-controller="flash">…</div>
//   <div class="alert fade show" data-controller="flash" data-flash-delay-value="5000">…</div>
export default class extends Controller {
  // Valeur paramétrable : 3 s par défaut, bon compromis lisibilité / discrétion.
  static values = { delay: { type: Number, default: 3000 } }

  connect() {
    // On garde la référence pour pouvoir annuler si le controller est déconnecté
    // avant la fin du délai (ex : navigation Turbo qui remplace le DOM).
    this.timeoutId = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }

  dismiss() {
    // Garde-fou : le controller peut être déconnecté juste avant cet appel.
    if (!this.element.isConnected) return

    // Retire `show` → Bootstrap applique la transition `opacity: 0`.
    this.element.classList.remove("show")

    // On retire l'élément du DOM une fois la transition terminée pour ne pas
    // couper brutalement l'animation. `once: true` auto-nettoie l'écouteur.
    // Fallback setTimeout au cas où `transitionend` ne serait pas émis
    // (préférences d'accessibilité désactivant les animations, par exemple).
    const cleanup = () => {
      if (this.element.isConnected) this.element.remove()
    }
    this.element.addEventListener("transitionend", cleanup, { once: true })
    setTimeout(cleanup, 300)
  }
}
