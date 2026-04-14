// frozen_string_literal: true

// Contrôleur Stimulus pour le formulaire "Nouvelle recherche".
//
// Responsabilités :
//   - Afficher/masquer les cartes de critères selon les sélections
//   - Générer les tags de résumé dans chaque sous-section (max 3 par section)
//   - Gérer la suppression d'un tag → retour de la carte dans la grille
//   - Gérer la spécificité Éducation : tags de niveaux scolaires + déblocage de la checkbox
//   - Mettre à jour l'affichage du slider de population
//   - Synchroniser les champs cachés coast / mountain / no_filters

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // ─── Cibles Stimulus ──────────────────────────────────────────────────────
  // Les "targets" sont des éléments du DOM que le contrôleur surveille.
  // On y accède via this.xxxTarget (unique) ou this.xxxTargets (liste).
  static targets = [
    "card",                  // chaque carte de critère (7 critères × 3 sections = 21 cards)
    "essentialTagsList",     // conteneur des tags dans le résumé "essentiel"
    "importantTagsList",     // conteneur des tags dans le résumé "important"
    "bonusTagsList",         // conteneur des tags dans le résumé "bonus"
    "essentialCount",        // compteur affiché (n/3) dans le résumé "essentiel"
    "importantCount",        // idem pour "important"
    "bonusCount",            // idem pour "bonus"
    "educationTagsDisplay",  // zone d'affichage des tags éducation (1 par copie de carte)
    "educationSelect",       // <select> dans chaque copie de la carte Éducation
    "educationCheckbox",     // checkbox de chaque copie de la carte Éducation
    "populationDisplay",     // texte affichant la valeur courante du slider
    "coastField",            // champ caché research[coast]
    "mountainField",         // champ caché research[mountain]
    "noFiltersField",        // champ caché research[no_filters]
    "educationHiddenField"   // champ caché pour le sous-tag dans éducation
  ]

  // ─── État interne ─────────────────────────────────────────────────────────
  // On stocke l'état dans des propriétés JS simples plutôt que dans le DOM
  // pour garder une source de vérité unique et facile à déboguer.

  // Dictionnaire { clé_critère: 'essential' | 'important' | 'bonus' }
  // Ex : { real_estate: 'important', health: 'bonus' }
  selections = {}

  // Liste des niveaux scolaires ajoutés dans la carte Éducation
  educationTags = []

  // ─── Cycle de vie ────────────────────────────────────────────────────────

  connect() {
    // ── 1. Restaure les niveaux scolaires depuis le champ caché JSON ──────────
    // Utilisé à la fois en mode création (valeur "[]") et en mode édition.
    if (this.hasEducationHiddenFieldTarget && this.educationHiddenFieldTarget.value) {
      try {
        this.educationTags = JSON.parse(this.educationHiddenFieldTarget.value)
      } catch (e) {
        this.educationTags = []
      }
    }

    // ── 2. Restaure les critères sélectionnés depuis les champs cachés ────────
    // En mode édition, les champs cachés contiennent les poids sauvegardés
    // (3 = essentiel, 2 = important, 1 = bonus, 0 = non sélectionné).
    // On reconstitue this.selections pour que renderAll() puisse reconstruire
    // l'interface (tags, compteurs, visibilité des cartes).
    const WEIGHT_TO_SECTION = { 3: 'essential', 2: 'important', 1: 'bonus' }
    this.element.querySelectorAll('[data-criterion-field]').forEach(field => {
      const key   = field.dataset.criterionField
      const value = parseInt(field.value, 10)
      if (value > 0 && WEIGHT_TO_SECTION[value]) {
        this.selections[key] = WEIGHT_TO_SECTION[value]
      }
    })

    // ── 3. Initialise l'affichage du slider de population ────────────────────
    // updatePopulation n'est déclenché que sur l'événement "input", donc il faut
    // initialiser manuellement l'étiquette au chargement (surtout en mode édition).
    const slider = this.element.querySelector('.population-slider')
    if (slider && this.hasPopulationDisplayTarget) {
      const value = parseInt(slider.value, 10) || 0
      const label = value === 0
        ? 'Toutes tailles'
        : value.toLocaleString('fr-FR') + '\u202fhab.'
      this.populationDisplayTargets.forEach(el => (el.textContent = label))
    }

    this.renderAll()
  }

  // ─── CRITÈRES : sélection ────────────────────────────────────────────────

  // Déclenché quand l'utilisateur coche une checkbox de critère.
  selectCriterion(event) {
    const checkbox = event.currentTarget
    // Sécurité : ignore les checkboxes désactivées (ex : Éducation sans tags)
    if (checkbox.disabled) {
      event.preventDefault()
      return
    }

    const key = checkbox.dataset.criterion  // ex : 'real_estate'
    const section = checkbox.dataset.section    // ex : 'essential'

    if (checkbox.checked) {
      // Vérifie la limite de 3 critères par section avant d'accepter la sélection
      const count = Object.values(this.selections).filter(s => s === section).length
      if (count >= 3) {
        checkbox.checked = false
        this.animateLimitReached(section)
        return
      }

      // Enregistre la sélection : ce critère appartient désormais à cette section
      this.selections[key] = section
    } else {
      // Désélection : on retire la clé du dictionnaire
      delete this.selections[key]
    }

    this.renderAll()
  }

  // Déclenché quand l'utilisateur clique le "×" d'un tag de résumé.
  // Le critère retrouve sa place dans toutes les grilles.
  removeTag(event) {
    const key = event.currentTarget.dataset.criterion
    delete this.selections[key]
    this.renderAll()
  }

  // ─── ÉDUCATION : spécificité ──────────────────────────────────────────────

  // Ajoute un niveau scolaire comme tag dans la carte Éducation.
  addEducationTag(event) {
    event.preventDefault()

    // Trouve le <select> dans la même carte que le bouton cliqué
    const card = event.currentTarget.closest('[data-criterion="education"]')
    const select = card.querySelector('[data-research-form-target="educationSelect"]')
    const value = select.value

    // Ignore si aucune valeur choisie ou déjà présente (pas de doublons)
    if (!value || this.educationTags.includes(value)) return

    this.educationTags.push(value)
    select.value = ''  // Remet le select sur l'option vide après ajout
    this.renderAll()
  }

  // Supprime un niveau scolaire de la liste. Si la liste devient vide,
  // la sélection Éducation est automatiquement annulée.
  removeEducationTag(event) {
    const value = event.currentTarget.dataset.tag
    this.educationTags = this.educationTags.filter(t => t !== value)

    // Si plus aucun niveau scolaire et que l'Éducation était sélectionnée,
    // on retire la sélection pour maintenir la cohérence de l'état
    if (this.educationTags.length === 0 && this.selections['education']) {
      delete this.selections['education']
    }

    this.renderAll()
  }

  // Transforme mon array educationTags en JSON pour rails

  updateEducationHiddenField() {
    if (this.hasEducationHiddenFieldTarget) {
      this.educationHiddenFieldTarget.value = JSON.stringify(this.educationTags)
    }
  }

  // ─── ACCORDÉON "En savoir plus" ───────────────────────────────────────────

  // Bascule l'affichage du détail d'une carte (sources & méthode de calcul).
  toggleAccordion(event) {
    event.preventDefault()
    const card = event.currentTarget.closest('.criterion-card')
    const body = card.querySelector('.criterion-card-accordion')
    const isOpen = !body.hidden
    body.hidden = isOpen
    event.currentTarget.textContent = isOpen ? 'En savoir plus ▾' : 'Réduire ▴'
  }

  // ─── SLIDER DE POPULATION ────────────────────────────────────────────────

  // Met à jour le texte affiché quand l'utilisateur déplace le slider.
  updatePopulation(event) {
    const value = parseInt(event.currentTarget.value, 10)
    // Si le slider est à 0, on affiche "Toutes tailles" (pas de filtre de population)
    const label = value === 0
      ? 'Toutes tailles'
      : value.toLocaleString('fr-FR') + '\u202fhab.'  // \u202f = espace fine insécable

    // Il peut y avoir plusieurs affichages si le composant est dupliqué
    this.populationDisplayTargets.forEach(el => (el.textContent = label))
  }

  // ─── FILTRE GÉOGRAPHIQUE ─────────────────────────────────────────────────

  // Synchronise les champs cachés (coast/mountain/no_filters) avec le radio bouton sélectionné.
  // Ces champs sont soumis avec le formulaire.
  updateGeoFilter(event) {
    const value = event.currentTarget.value
    this.coastFieldTarget.value = value === 'coast' ? '1' : '0'
    this.mountainFieldTarget.value = value === 'mountain' ? '1' : '0'
    this.noFiltersFieldTarget.value = value === 'indifferent' ? '1' : '0'
  }



  // Masque toutes les copies d'un critère sélectionné (dans les 3 sections).
  updateCardVisibility() {

    // Petit fix. 
    // Après suppression d’un tag, la clé disparaît de this.selections.
    // On doit donc reconstruire toutes les checkboxes en fonction de this.selections :
    // une checkbox est cochée uniquement si sa clé est présente dans this.selections
    // et associée à la même section.

    const checkboxes = document.querySelectorAll('[data-criterion]')

    checkboxes.forEach(checkbox => {
      const key = checkbox.dataset.criterion
      const section = checkbox.dataset.section

      checkbox.checked = this.selections[key] === section
    })

    this.cardTargets.forEach(card => {
      const isSelected = !!this.selections[card.dataset.criterion]
      card.hidden = isSelected
    })
  }

  // Reconstruit les listes de tags de résumé pour chaque section.
  updateTagsLists() {
    const containers = {
      essential: this.essentialTagsListTarget,
      important: this.importantTagsListTarget,
      bonus: this.bonusTagsListTarget
    }

    Object.entries(containers).forEach(([section, container]) => {
      // Récupère tous les critères sélectionnés dans cette section
      const selected = Object.entries(this.selections)
        .filter(([, s]) => s === section)

      // Génère le HTML des tags (couleur + titre + bouton de suppression)
      container.innerHTML = selected.map(([key]) => {
        // Cherche la première carte correspondante (peu importe la section) pour les métadonnées
        const card = this.cardTargets.find(c => c.dataset.criterion === key)
        const title = card ? card.dataset.title : key
        const color = card ? card.dataset.color : '#ccc'

        return `
          <span class="criterion-tag" style="--tag-color: ${color}">
            ${title}
            <button type="button"
                    class="criterion-tag-remove"
                    data-action="click->research-form#removeTag"
                    data-criterion="${key}"
                    aria-label="Supprimer le critère ${title}">×</button>
          </span>
        `
      }).join('')
    })
  }

  // Met à jour les compteurs n/3 dans les résumés.
  updateCounts() {
    const counts = { essential: 0, important: 0, bonus: 0 }
    Object.values(this.selections).forEach(section => {
      if (counts[section] !== undefined) counts[section]++
    })
    this.essentialCountTarget.textContent = counts.essential
    this.importantCountTarget.textContent = counts.important
    this.bonusCountTarget.textContent = counts.bonus
  }

  // Met à jour le contenu de toutes les copies de la carte Éducation :
  //   - affiche les tags de niveaux scolaires
  //   - désactive les options déjà sélectionnées dans le <select>
  updateEducationCards() {
    // Même liste de tags dans chaque copie de la carte
    this.educationTagsDisplayTargets.forEach(container => {
      container.innerHTML = this.educationTags.map(tag => `
        <span class="education-inner-tag">
          ${tag}
          <button type="button"
                  class="education-inner-tag-remove"
                  data-action="click->research-form#removeEducationTag"
                  data-tag="${tag}"
                  aria-label="Supprimer ${tag}">×</button>
        </span>
      `).join('')
    })

    // Désactive dans chaque <select> les options déjà ajoutées comme tags
    this.educationSelectTargets.forEach(select => {
      Array.from(select.options).forEach(opt => {
        if (!opt.value) return  // ignore l'option vide "Choisir un niveau…"
        opt.disabled = this.educationTags.includes(opt.value)
      })
    })
  }

  // Active/désactive les checkboxes Éducation selon la présence de tags.
  // La checkbox est grisée tant qu'aucun niveau scolaire n'est précisé.
  updateEducationCheckboxes() {
    const canSelect = this.educationTags.length > 0

    this.educationCheckboxTargets.forEach(cb => {
      cb.disabled = !canSelect
      const wrapper = cb.closest('.criterion-card-checkbox-wrapper')
      if (wrapper) wrapper.classList.toggle('checkbox-disabled', !canSelect)
    })
  }

  // ─── CHAMPS CACHÉS : valeurs entières pour le serveur ────────────────────

  // Traduit l'état JS (this.selections) en valeurs entières dans les <input type="hidden">.
  // C'est ce qui permet au contrôleur Rails de recevoir des integers propres :
  //   essentiel = 3 | important = 2 | bonus = 1 | non sélectionné = 0
  updateCriterionFields() {
    const WEIGHTS = { essential: 3, important: 2, bonus: 1 }

    // On cible tous les champs cachés portant l'attribut data-criterion-field
    this.element.querySelectorAll('[data-criterion-field]').forEach(field => {
      const key = field.dataset.criterionField
      const section = this.selections[key]   // undefined si non sélectionné
      field.value = section ? (WEIGHTS[section] ?? 0) : 0
    })
  }

  // ─── Animations / feedback visuel ────────────────────────────────────────

  // Secoue légèrement le titre de la sous-section quand la limite de 3 est atteinte.
  animateLimitReached(section) {
    const el = this.element.querySelector(`[data-section-key="${section}"]`)
    if (!el) return
    el.classList.add('limit-reached')
    setTimeout(() => el.classList.remove('limit-reached'), 600)
  }


  // ─── RENDU : méthode centrale ─────────────────────────────────────────────

  // Appelée après chaque changement d'état pour mettre à jour l'ensemble du DOM.
  // On repart de l'état JS et on reconstruit les parties dynamiques.
  renderAll() {
    this.updateEducationHiddenField()
    this.updateCardVisibility()
    this.updateTagsLists()
    this.updateCounts()
    this.updateEducationCards()
    this.updateEducationCheckboxes()
    this.updateCriterionFields()
  }
}
