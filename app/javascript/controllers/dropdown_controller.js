import { Controller } from "@hotwired/stimulus";

//TODO First test of stimulus controller not currently being used
export default class extends Controller {
  static targets = ["menu-test"];

  connect() {
    this.element.addEventListener("click", this.toggle);
  }

  disconnect() {
    this.element.removeEventListener("click", this.toggle);
  }

  toggle = () => {
    if (this.menuTestTarget) {
      this.menuTestTarget.classList.toggle("show");
    }
  };
}
