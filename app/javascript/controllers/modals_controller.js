import { Controller } from "@hotwired/stimulus";
import interact from "interactjs";

// Connects to data-controller="modals"
export default class extends Controller {
  connect() {
    // this.makeModalDraggable();
    // this.element.addEventListener("click", this.handleDelete.bind(this));
  }

  //! Temporary Off because dragging makes modal shift away
  //TODO find way to make modal stay in place on click
  makeModalDraggable() {
    const modal = document.getElementById("draggable-modal");
    if (!modal) return;

    let startX = 0;
    let startY = 0;
    let modalX = 0;
    let modalY = 0;

    interact(modal).draggable({
      ignoreFrom: [".cancel-button", ".btn"],
      listeners: {
        start(event) {
          // Save the initial click position
          startX = event.clientX;
          startY = event.clientY;

          // Get the current modal position
          const transformValues = modal.style.transform.split(/\w+\(|\);?/);
          if (transformValues[1]) {
            const [modalXStr, modalYStr] = transformValues[1].split("px,");
            modalX = parseFloat(modalXStr);
            modalY = parseFloat(modalYStr);
          }
        },
        move(event) {
          // Calculate the new position based on the initial click position and modal's current position
          const newX = modalX + event.clientX - startX;
          const newY = modalY + event.clientY - startY;
          // Update the modal's position
          modal.style.transform = `translate(${newX}px, ${newY}px)`;
        },
      },
    });
  }

  close(e) {
    if (e) e.preventDefault();
    const modal = document.getElementById("modal");
    modal.innerHTML = "";
    modal.removeAttribute("src");
    modal.removeAttribute("complete");
  }

  // Customer edit: "Add New Activity" is a second form; block Close/Save if draft text exists.
  guardUnsavedActivityNoteBeforeLeave(event) {
    const root =
      document.getElementById("draggable-modal") || this.element || document;
    const ta = root.querySelector(
      "#activity-notes-partial-container form textarea.activity-note-form-textarea",
    );
    if (!ta) return;
    if (ta.value.trim() === ta.defaultValue.trim()) return;
    if (
      !window.confirm(
        "You have an unsaved activity note. Are you sure you want to leave?",
      )
    ) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }

  // This is the new Router from the modal!
  async handleSubmit(event) {
    event.preventDefault();
    const form = event.target;

    try {
      const formData = new FormData(form);
      const response = await fetch(form.action, {
        method: form.method,
        body: formData,
        headers: {
          Accept: "application/json",
        },
        credentials: "same-origin",
      });

      if (!response.ok) {
        const errorMessage = await response.json();
        // Handle error messages or other actions for failed deletions
        console.error("Error:", errorMessage);
        // Display error message or handle failure
        return;
      }

      const responseData = await response.json();

      if responseData.redirect) {
        const modal = document.getElementById("modal");
        if (modal) {
          modal.innerHTML = "";
          modal.removeAttribute("src");
          modal.removeAttribute("complete");
        }
        window.location.replace(responseData.redirect);
      }
    } catch (error) {
      console.error("Error:", error);
      // Handle errors
    }
  }

  async handleDelete(event) {
    event.preventDefault();

    const link = event.currentTarget;
    const url = link.getAttribute("href");
    const method = (
      link.getAttribute("data-turbo-method") ||
      (url.includes("/archive") ? "post" : "delete")
    ).toUpperCase();

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
          Accept: "application/json",
        },
        credentials: "same-origin",
      });

      if (!response.ok) {
        const errorMessage = await response.json().catch(() => ({}));
        console.error("Error:", errorMessage);
        return;
      }

      const responseData = await response.json();

      if (responseData.redirect) {
        window.location.replace(responseData.redirect);
      }
    } catch (error) {
      console.error("Error:", error);
    }
  }
}
