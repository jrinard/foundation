import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";
import { put } from "@rails/request.js";

// Connects to data-controller="sortable"
export default class extends Controller {
  static values = {
    group: String,
  };

  connect() {
    if (this.isMobileDevice() && this.element.id === "mobile-sort-off") {
      this.element.classList.remove("sortable");
      this.element.removeAttribute("data-controller");
    } else {
      // Initialize sortable on non-mobile devices
      Sortable.create(this.element, {
        onEnd: this.onEnd.bind(this),
        group: this.groupValue,
        animation: 150,
      });
    }
  }

  onEnd(event) {
    var sortableUpdateUrl = event.item.dataset.sortableUpdateUrl;
    // console.log(sortableUpdateUrl)
    // console.log(event.newIndex)
    var sortableListId = event.to.dataset.sortableListId;
    console.log(event.to.dataset.sortableListId);

    put(sortableUpdateUrl, {
      body: JSON.stringify({
        row_order_position: event.newIndex,
        list_id: sortableListId,
      }),
    });
  }

  isMobileDevice() {
    // Check if the device is mobile based on screen width

    const isMobile = window.innerWidth <= 767;
    console.log("=== isMobile disabling lead sort", isMobile);
    return isMobile;
  }
}
