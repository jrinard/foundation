import { Controller } from "@hotwired/stimulus";

// Shows a hint next to the activity toolbar when the new-note draft has any characters.
export default class extends Controller {
  static targets = ["hint"];

  connect() {
    this.textarea = this.element.querySelector(
      "textarea.activity-note-form-textarea",
    );
    if (!this.textarea || !this.hasHintTarget) return;
    this.boundUpdate = this.update.bind(this);
    this.textarea.addEventListener("input", this.boundUpdate);
    this.update();
  }

  disconnect() {
    if (this.textarea && this.boundUpdate) {
      this.textarea.removeEventListener("input", this.boundUpdate);
    }
  }

  update() {
    if (!this.hasHintTarget) return;
    this.hintTarget.hidden = this.textarea.value.length === 0;
  }
}
