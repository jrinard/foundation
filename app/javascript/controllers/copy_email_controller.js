import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    console.log("Controller connected!");
  }

  copyEmail() {
    console.log("Copy Email function called");
    const copyText = this.element.dataset.copyEmailText;
    navigator.clipboard.writeText(copyText).then(() => {
      console.log("Email copied:", copyText);
    });
  }
}
