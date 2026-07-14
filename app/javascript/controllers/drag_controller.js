//! Not Currently being used

import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";
import { patch } from "@rails/request.js";

export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      group: "shared",
      animation: 150,
      // onStart: this.start.bind(this),
      onEnd: this.end.bind(this),
    });
  }

  async end(event) {
    let id = event.item.dataset.id;
    let newIndex = event.newIndex + 1;

    //TODO In this version they change column everytime
    //TODO Find way to make them stay in the column
    //* Current Version moves columns but does not stay in same group
    let columnChosen;

    //Investigate const sourceColumn = event.from.dataset.sortableListId;
    if (event.from === event.to) {
      // No change in column, keep the current 'active' value
      if (this.element.dataset.dragGroup === "column1") {
        columnChosen = true;
      } else if (this.element.dataset.dragGroup === "column2") {
        columnChosen = false;
      }
    } else {
      // Item is moved to a different column, update 'active' accordingly
      if (this.element.dataset.dragGroup === "column1") {
        columnChosen = true;
      } else if (this.element.dataset.dragGroup === "column2") {
        columnChosen = false;
      }
    }
    // //*

    try {
      const response = await patch(this.data.get("url").replace(":id", id), {
        body: { position: newIndex, active: columnChosen },
      });

      // Handle response if needed
    } catch (error) {
      console.log("=== Drag and Drop error in drag_controller", response);
    }
  }
}
