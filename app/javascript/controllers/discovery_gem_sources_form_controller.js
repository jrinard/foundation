import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["save"];

  connect() {
    this.initialState = this.readState();
    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
    this.element.addEventListener("change", this.handleChange);
    this.element.addEventListener("submit", this.handleSubmit);
  }

  disconnect() {
    this.element.removeEventListener("change", this.handleChange);
    this.element.removeEventListener("submit", this.handleSubmit);
  }

  handleChange(event) {
    if (!event.target.matches(".discovery-gem-source-checkbox")) return;
    this.syncDirtyState();
  }

  handleSubmit() {
    if (this.hasSaveTarget) {
      this.saveTarget.classList.remove("is-dirty");
    }
    this.initialState = this.readState();
  }

  readState() {
    return Array.from(this.element.querySelectorAll(".discovery-gem-source-checkbox"))
      .map((checkbox) => `${checkbox.name}=${checkbox.checked}`)
      .join("&");
  }

  syncDirtyState() {
    const dirty = this.readState() !== this.initialState;
    if (this.hasSaveTarget) {
      this.saveTarget.classList.toggle("is-dirty", dirty);
    }
  }
}
