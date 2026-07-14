import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  copyPhone() {
    console.log("=== Copy phone function called");
    const copyText = this.element.dataset.copyPhoneText;
    navigator.clipboard.writeText(copyText).then(() => {
      console.log("Text copied:", copyText);
    });
  }
}
