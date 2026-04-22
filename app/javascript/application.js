// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chatbot_widget"
import "@popperjs/core"
import "bootstrap"

// Remplace la boîte de confirmation native du navigateur (window.confirm) par
// notre modale Move On chaque fois qu'un élément HTML porte data-turbo-confirm.
// Turbo.config.forms.confirm doit renvoyer une Promise<boolean> :
//   - true  → Turbo soumet le formulaire (suppression confirmée)
//   - false → Turbo annule la soumission
//
// Bootstrap (UMD) s'attache à window.bootstrap — on utilise window.bootstrap.Modal
// plutôt qu'un import nommé car le bundle UMD n'exporte pas d'ES modules.
Turbo.config.forms.confirm = (_message, _element) => {
  return new Promise((resolve) => {
    const modalEl    = document.getElementById("confirmDeleteModal");
    const confirmBtn = document.getElementById("confirmDeleteBtn");
    const bsModal    = new window.bootstrap.Modal(modalEl);

    // On utilise un flag pour distinguer "confirmé" de "fermé autrement"
    let confirmed = false;

    const onConfirm = () => {
      confirmed = true;
      bsModal.hide(); // déclenche l'événement hidden.bs.modal ci-dessous
    };

    // hidden.bs.modal se déclenche quelle que soit la façon de fermer le modal
    // (clic sur Annuler, croix, touche Échap, clic sur le backdrop)
    const onHidden = () => {
      resolve(confirmed);
      confirmBtn.removeEventListener("click", onConfirm);
    };

    confirmBtn.addEventListener("click", onConfirm, { once: true });
    modalEl.addEventListener("hidden.bs.modal", onHidden, { once: true });

    bsModal.show();
  });
};
