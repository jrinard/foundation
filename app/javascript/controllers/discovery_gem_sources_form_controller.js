import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["save", "status"];

  connect() {
    this.initialState = this.readState();
    this.handleChange = this.handleChange.bind(this);
    this.element.addEventListener("change", this.handleChange);
  }

  disconnect() {
    this.element.removeEventListener("change", this.handleChange);
  }

  handleChange(event) {
    if (!event.target.matches(".discovery-gem-source-checkbox")) return;
    this.syncDirtyState();
  }

  async submitSave(event) {
    event.preventDefault();

    if (this.hasSaveTarget) {
      this.saveTarget.disabled = true;
      this.saveTarget.classList.add("is-saving");
      this.saveTarget.value = "Saving...";
    }
    this.clearStatus();

    try {
      const response = await fetch(this.element.action, {
        method: "PATCH",
        body: new FormData(this.element),
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      });

      const data = await response.json();

      if (!response.ok || !data.ok) {
        this.showStatus(data.message || "Could not save discovery source settings.", "error");
        return;
      }

      this.initialState = this.readState();
      if (this.hasSaveTarget) {
        this.saveTarget.classList.remove("is-dirty");
      }
      this.showStatus(data.message, "ok");
    } catch (error) {
      this.showStatus(`Save failed: ${error.message}`, "error");
    } finally {
      if (this.hasSaveTarget) {
        this.saveTarget.disabled = false;
        this.saveTarget.classList.remove("is-saving");
        this.saveTarget.value = "Save";
      }
    }
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

  showStatus(message, type) {
    if (!this.hasStatusTarget) return;

    this.statusTarget.textContent = message;
    this.statusTarget.hidden = false;
    this.statusTarget.classList.remove("is-ok", "is-error");
    this.statusTarget.classList.add(type === "ok" ? "is-ok" : "is-error");
  }

  clearStatus() {
    if (!this.hasStatusTarget) return;

    this.statusTarget.textContent = "";
    this.statusTarget.hidden = true;
    this.statusTarget.classList.remove("is-ok", "is-error");
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }
}
