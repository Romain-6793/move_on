// Contrôleur Stimulus pour l'étape 3 du wizard (priorités).
//
// Responsabilités :
//   - Gérer la mutuelle exclusivité entre les grilles "Important" et "Bonus" :
//     cocher l'un décoche l'autre ET masque la card dans l'autre grille.
//   - Mettre à jour les champs cachés research[critère] avec la bonne valeur :
//       2 = important  |  1 = bonus  |  0 = non retenu
//   - Gérer la spécificité Éducation :
//     * sélection de niveaux scolaires avant activation de la checkbox (comme à l'étape 2)
//     * les niveaux sont partagés entre les deux instances de la card Éducation
//     * 3 niveaux cochés = toujours 1 seul critère (valeur 2 ou 1, jamais 6)

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "importantCheckbox",    // checkboxes "Important pour moi" (toutes)
    "bonusCheckbox",        // checkboxes "Bonus pour moi" (toutes)
    "hiddenField",          // champs cachés research[criterion_key] → 0 / 1 / 2
    "importantCard",        // div carte dans la grille "Important" (une par critère)
    "bonusCard",            // div carte dans la grille "Bonus" (une par critère)
    "educationTagsDisplay", // zones d'affichage des tags de niveaux (une par card éducation)
    "educationSelect",      // <select> des niveaux scolaires (un par card éducation)
    "educationHidden"       // champ caché JSON education_levels (unique dans le formulaire)
  ]

  // Niveaux scolaires sélectionnés — partagés entre les deux cards Éducation
  educationLevels = []

  // ─── Cycle de vie ─────────────────────────────────────────────────────────

  connect() {
    // Restaure les niveaux depuis le champ caché JSON (données de l'étape 2, ou retour arrière)
    if (this.hasEducationHiddenTarget) {
      try {
        this.educationLevels = JSON.parse(this.educationHiddenTarget.value) || []
      } catch {
        this.educationLevels = []
      }
    }

    this.renderEducationTags()
    this.updateEducationCheckboxes()

    // Applique la visibilité initiale des cards selon les valeurs déjà enregistrées.
    // Utile quand l'utilisateur revient en arrière dans le wizard.
    this.importantCheckboxTargets.forEach(cb => {
      if (cb.checked) {
        const bonusCard = this.bonusCardTargets.find(c => c.dataset.criterion === cb.dataset.criterion)
        if (bonusCard) bonusCard.hidden = true
      }
    })
    this.bonusCheckboxTargets.forEach(cb => {
      if (cb.checked) {
        const importantCard = this.importantCardTargets.find(c => c.dataset.criterion === cb.dataset.criterion)
        if (importantCard) importantCard.hidden = true
      }
    })
  }

  // ─── Sélection "Important" ────────────────────────────────────────────────

  // Déclenché sur change de n'importe quelle checkbox "Important pour moi"
  // data-action="change->wizard-priorities#toggleImportant"
  toggleImportant(event) {
    const checkbox = event.currentTarget
    const key = checkbox.dataset.criterion

    // La card bonus correspondante est masquée/réaffichée pour éviter la double sélection
    const bonusCard = this.bonusCardTargets.find(c => c.dataset.criterion === key)

    if (checkbox.checked) {
      const bonusCheckbox = this.bonusCheckboxTargets.find(cb => cb.dataset.criterion === key)
      if (bonusCheckbox) bonusCheckbox.checked = false
      if (bonusCard) bonusCard.hidden = true

      this.updateHiddenField(key, 2)  // valeur 2 = important
    } else {
      // Le critère redevient disponible dans la grille bonus
      if (bonusCard) bonusCard.hidden = false
      this.updateHiddenField(key, 0)
    }
  }

  // ─── Sélection "Bonus" ───────────────────────────────────────────────────

  // Déclenché sur change de n'importe quelle checkbox "Bonus pour moi"
  // data-action="change->wizard-priorities#toggleBonus"
  toggleBonus(event) {
    const checkbox = event.currentTarget
    const key = checkbox.dataset.criterion

    // Symétrique : cocher bonus masque la card dans la grille important
    const importantCard = this.importantCardTargets.find(c => c.dataset.criterion === key)

    if (checkbox.checked) {
      const importantCheckbox = this.importantCheckboxTargets.find(cb => cb.dataset.criterion === key)
      if (importantCheckbox) importantCheckbox.checked = false
      if (importantCard) importantCard.hidden = true

      this.updateHiddenField(key, 1)  // valeur 1 = bonus
    } else {
      if (importantCard) importantCard.hidden = false
      this.updateHiddenField(key, 0)
    }
  }

  // ─── Éducation : ajout d'un niveau scolaire ──────────────────────────────

  // data-action="click->wizard-priorities#addEducationLevel"
  addEducationLevel(event) {
    event.preventDefault()

    // Trouve le <select> de la même card que le bouton cliqué (important ou bonus)
    const card = event.currentTarget.closest('.wizard-criterion-card')
    const select = card?.querySelector('[data-wizard-priorities-target="educationSelect"]')
    const value = select?.value

    if (!value || this.educationLevels.includes(value)) return

    this.educationLevels.push(value)

    // Réinitialise tous les selects éducation (les deux grilles sont synchronisées)
    this.educationSelectTargets.forEach(s => { s.value = '' })

    this.renderEducationTags()
    this.updateEducationHidden()
    this.updateEducationCheckboxes()
  }

  // ─── Éducation : suppression d'un tag ─────────────────────────────────────

  // data-action="click->wizard-priorities#removeEducationLevel"
  removeEducationLevel(event) {
    const value = event.currentTarget.dataset.tag
    this.educationLevels = this.educationLevels.filter(t => t !== value)

    // Si plus aucun niveau, les checkboxes éducation doivent être décochées et grisées
    if (this.educationLevels.length === 0) {
      const importantEduCb = this.importantCheckboxTargets.find(cb => cb.dataset.criterion === 'education')
      const bonusEduCb     = this.bonusCheckboxTargets.find(cb => cb.dataset.criterion === 'education')

      if (importantEduCb?.checked) {
        importantEduCb.checked = false
        // Ré-affiche la card bonus éducation (elle avait été masquée)
        const bonusCard = this.bonusCardTargets.find(c => c.dataset.criterion === 'education')
        if (bonusCard) bonusCard.hidden = false
        this.updateHiddenField('education', 0)
      }

      if (bonusEduCb?.checked) {
        bonusEduCb.checked = false
        // Ré-affiche la card important éducation
        const importantCard = this.importantCardTargets.find(c => c.dataset.criterion === 'education')
        if (importantCard) importantCard.hidden = false
        this.updateHiddenField('education', 0)
      }
    }

    this.renderEducationTags()
    this.updateEducationHidden()
    this.updateEducationCheckboxes()
  }

  // ─── Méthodes privées (helpers) ───────────────────────────────────────────

  // Retrouve le champ caché par clé de critère et met sa valeur à jour
  updateHiddenField(criterionKey, value) {
    const field = this.hiddenFieldTargets.find(f => f.dataset.criterion === criterionKey)
    if (field) field.value = value
  }

  // Met à jour TOUTES les zones de tags éducation (une par card éducation visible)
  renderEducationTags() {
    const tagsHtml = this.educationLevels.map(tag => `
      <span class="wizard-edu-tag">
        ${tag}
        <button type="button"
                class="wizard-edu-tag-remove"
                data-action="click->wizard-priorities#removeEducationLevel"
                data-tag="${tag}"
                aria-label="Supprimer ${tag}">×</button>
      </span>
    `).join('')

    // Injecte les tags dans les deux affichages (important + bonus)
    this.educationTagsDisplayTargets.forEach(display => {
      display.innerHTML = tagsHtml
    })

    // Désactive les options déjà sélectionnées dans tous les selects
    this.educationSelectTargets.forEach(select => {
      Array.from(select.options).forEach(opt => {
        if (!opt.value) return
        opt.disabled = this.educationLevels.includes(opt.value)
      })
    })
  }

  // Enregistre les niveaux scolaires en JSON dans le champ caché (unique dans le formulaire)
  updateEducationHidden() {
    if (this.hasEducationHiddenTarget) {
      this.educationHiddenTarget.value = JSON.stringify(this.educationLevels)
    }
  }

  // Active ou grise les checkboxes éducation selon la présence de niveaux scolaires.
  // Peu importe le nombre de niveaux : éducation vaut toujours 1 critère (valeur 2 ou 1).
  updateEducationCheckboxes() {
    const canSelect = this.educationLevels.length > 0

    const importantEduCb = this.importantCheckboxTargets.find(cb => cb.dataset.criterion === 'education')
    if (importantEduCb) {
      importantEduCb.disabled = !canSelect
      const label = importantEduCb.closest('.wizard-checkbox-label')
      if (label) label.classList.toggle('wizard-checkbox-disabled', !canSelect)
    }

    const bonusEduCb = this.bonusCheckboxTargets.find(cb => cb.dataset.criterion === 'education')
    if (bonusEduCb) {
      bonusEduCb.disabled = !canSelect
      const label = bonusEduCb.closest('.wizard-checkbox-label')
      if (label) label.classList.toggle('wizard-checkbox-disabled', !canSelect)
    }
  }
}
