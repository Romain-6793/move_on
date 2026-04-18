// Contrôleur Stimulus pour l'étape 2 du wizard (critères essentiels).
//
// Responsabilités :
//   - Compter les critères essentiels cochés (max 3)
//   - Bloquer la sélection si la limite est atteinte
//   - Mettre à jour les champs cachés avec les valeurs 3 (essentiel) ou 0
//   - Gérer la spécificité Éducation : tags de niveaux + activation de la checkbox
//
// Wicked : Stimulus Values API — "limit-value" est injecté via
//   data-wizard-essentials-limit-value="3" sur l'élément contrôleur.
//   On utilise une constante locale à la place pour plus de clarté.

import { Controller } from "@hotwired/stimulus"

// Nombre maximum de critères essentiels autorisés
const MAX_ESSENTIALS = 3

export default class extends Controller {
  static targets = [
    "card",               // chaque carte de critère
    "count",              // texte affichant le compteur n/3
    "limitAlert",         // message d'alerte quand la limite est atteinte
    "hiddenField",        // champ caché research[criterion_key] = 3 ou 0
    "educationBlock",     // bloc de sélection des niveaux scolaires
    "educationSelect",    // <select> des niveaux
    "educationCheckbox",  // checkbox "Essentiel" de la carte Éducation
    "educationTagsDisplay", // zone d'affichage des tags de niveaux
    "educationHidden"     // champ caché research[education_levels] (JSON)
  ]

  // Liste des niveaux scolaires ajoutés — initialisée au connect() depuis le champ caché
  educationLevels = []

  // ─── Cycle de vie ─────────────────────────────────────────────────────────

  connect() {
    // Restaure les niveaux scolaires depuis le champ caché JSON (mode édition ou retour arrière)
    if (this.hasEducationHiddenTarget) {
      try {
        this.educationLevels = JSON.parse(this.educationHiddenTarget.value) || []
      } catch {
        this.educationLevels = []
      }
    }

    // Calcule le compteur initial à partir des checkboxes déjà cochées (retour arrière)
    this.updateCounter()
    // Affiche les tags d'éducation déjà enregistrés
    this.renderEducationTags()
    // Synchronise l'état de la checkbox éducation
    this.updateEducationCheckbox()
  }

  // ─── Sélection / désélection d'un critère essentiel ───────────────────────

  // Déclenché sur "change" de chaque checkbox
  // data-action="change->wizard-essentials#toggleEssential"
  toggleEssential(event) {
    const checkbox = event.currentTarget
    const key      = checkbox.dataset.criterion

    if (checkbox.checked) {
      // Attention : quand l'événement "change" se déclenche, le navigateur a DÉJÀ
      // mis checkbox.checked = true. countSelected() compte donc le critère
      // qu'on vient de cocher. On utilise > (strict) et non >= pour autoriser
      // exactement MAX_ESSENTIALS sélections sans bloquer la dernière.
      const currentCount = this.countSelected()
      if (currentCount > MAX_ESSENTIALS) {
        // Annule le clic et affiche le message d'alerte
        checkbox.checked = false
        this.showLimitAlert()
        return
      }
    }

    this.hideLimitAlert()
    this.updateHiddenField(key, checkbox.checked ? 3 : 0)
    this.updateCounter()
  }

  // ─── Éducation : ajout d'un niveau scolaire ──────────────────────────────

  addEducationTag(event) {
    event.preventDefault()
    const value = this.educationSelectTarget.value
    if (!value || this.educationLevels.includes(value)) return

    this.educationLevels.push(value)
    this.educationSelectTarget.value = '' // remet le select à vide
    this.renderEducationTags()
    this.updateEducationHidden()
    this.updateEducationCheckbox()
  }

  // ─── Éducation : suppression d'un tag ────────────────────────────────────

  // data-action="click->wizard-essentials#removeEducationTag"
  removeEducationTag(event) {
    const value = event.currentTarget.dataset.tag
    this.educationLevels = this.educationLevels.filter(t => t !== value)

    // Si plus aucun niveau scolaire et la checkbox est cochée → la décocher
    if (this.educationLevels.length === 0 && this.educationCheckboxTarget.checked) {
      this.educationCheckboxTarget.checked = false
      this.updateHiddenField('education', 0)
      this.updateCounter()
    }

    this.renderEducationTags()
    this.updateEducationHidden()
    this.updateEducationCheckbox()
  }

  // ─── Méthodes privées (helpers) ───────────────────────────────────────────

  // Compte les checkboxes actuellement cochées
  countSelected() {
    return this.element.querySelectorAll('.wizard-criterion-checkbox:checked').length
  }

  // Met à jour le texte du compteur n/MAX_ESSENTIALS
  updateCounter() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.countSelected()
    }
  }

  // Met à jour la valeur du champ caché pour un critère donné
  updateHiddenField(criterionKey, value) {
    const field = this.hiddenFieldTargets.find(f => f.dataset.criterion === criterionKey)
    if (field) field.value = value
  }

  showLimitAlert() {
    if (this.hasLimitAlertTarget) {
      this.limitAlertTarget.hidden = false
      // Cache automatiquement l'alerte après 3 secondes
      setTimeout(() => this.hideLimitAlert(), 3000)
    }
  }

  hideLimitAlert() {
    if (this.hasLimitAlertTarget) {
      this.limitAlertTarget.hidden = true
    }
  }

  // Génère les tags HTML des niveaux scolaires dans la carte Éducation
  renderEducationTags() {
    if (!this.hasEducationTagsDisplayTarget) return

    this.educationTagsDisplayTarget.innerHTML = this.educationLevels.map(tag => `
      <span class="wizard-edu-tag">
        ${tag}
        <button type="button"
                class="wizard-edu-tag-remove"
                data-action="click->wizard-essentials#removeEducationTag"
                data-tag="${tag}"
                aria-label="Supprimer ${tag}">×</button>
      </span>
    `).join('')

    // Désactive dans le select les options déjà sélectionnées
    if (this.hasEducationSelectTarget) {
      Array.from(this.educationSelectTarget.options).forEach(opt => {
        if (!opt.value) return
        opt.disabled = this.educationLevels.includes(opt.value)
      })
    }
  }

  // Enregistre les niveaux scolaires en JSON dans le champ caché
  updateEducationHidden() {
    if (this.hasEducationHiddenTarget) {
      this.educationHiddenTarget.value = JSON.stringify(this.educationLevels)
    }
  }

  // Active/désactive la checkbox Éducation selon la présence de tags
  updateEducationCheckbox() {
    if (!this.hasEducationCheckboxTarget) return
    const canSelect = this.educationLevels.length > 0
    this.educationCheckboxTarget.disabled = !canSelect

    // Met à jour la classe CSS pour l'apparence grisée
    const label = this.educationCheckboxTarget.closest('.wizard-checkbox-label')
    if (label) label.classList.toggle('wizard-checkbox-disabled', !canSelect)
  }
}
