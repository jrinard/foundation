import { Controller } from "@hotwired/stimulus";
// app/javascript/controllers/autoresize_controller.js

console.log("=== Stimulus Auto Resize Loaded =");

export default class extends Controller {
  static targets = ["textarea"];

  connect() {
    this.resize();
  }

  resize() {
    this.textareaTarget.style.height = "auto";
    this.textareaTarget.style.height = `${this.textareaTarget.scrollHeight}px`;
  }

  adjust() {
    this.resize();
  }
}
