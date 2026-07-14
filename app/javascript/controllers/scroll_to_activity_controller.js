import { Controller } from "@hotwired/stimulus";

// When the customer edit modal loads with "Add New Activity" (view_notes param),
// scroll the modal to the activity notes section so the form is visible.
export default class extends Controller {
  static values = { show: Boolean };

  connect() {
    if (!this.showValue) return;

    const modal = this.element;
    if (!modal) return;

    // Run after layout/paint so the activity section is in the DOM
    requestAnimationFrame(() => {
      const target = document.getElementById("activity-notes-partial-container");
      if (target && modal.contains(target)) {
        // Scroll the modal so the activity section is at the bottom of the visible area
        const targetBottom = target.offsetTop + target.offsetHeight;
        const scrollBottom = modal.scrollTop + modal.clientHeight;
        modal.scrollTop = targetBottom - modal.clientHeight;
      } else {
        modal.scrollTop = modal.scrollHeight;
      }
    });
  }
}
