import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "labelInput", "filenameHint"];

  prepareEdit(event) {
    event.stopPropagation();
    const button = event.currentTarget;
    this.editButton = button;

    if (this.hasLabelInputTarget) {
      this.labelInputTarget.value = button.dataset.label || "";
    }

    if (this.hasFilenameHintTarget) {
      this.filenameHintTarget.textContent = `File: ${button.dataset.filename || "—"}`;
    }

    if (this.hasFormTarget && button.dataset.updateUrl) {
      this.formTarget.action = button.dataset.updateUrl;
    }
  }

  async submitLabel(event) {
    event.preventDefault();

    if (!this.hasFormTarget) return;

    const form = this.formTarget;
    const submitButton = form.querySelector('[type="submit"]');
    if (submitButton) submitButton.disabled = true;

    try {
      const response = await fetch(form.action, {
        method: "PATCH",
        body: new FormData(form),
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      });

      const data = await response.json();

      if (!response.ok || !data.ok) {
        window.alert(data.message || "Could not save label.");
        return;
      }

      this.updateRowLabel(data);
      this.closeModal();
    } catch (error) {
      window.alert(`Save failed: ${error.message}`);
    } finally {
      if (submitButton) submitButton.disabled = false;
    }
  }

  updateRowLabel(data) {
    const row = this.editButton?.closest("tr");
    if (!row) return;

    const labelCell = row.querySelector(".discovery-mountain-gems-file-label");
    const labelName = labelCell?.querySelector(".discovery-mountain-gems-file-label-name");
    const labelFull = labelCell?.querySelector(".discovery-mountain-gems-file-label-full");
    if (labelName) labelName.textContent = data.display_label;
    if (labelFull) labelFull.textContent = data.display_label;

    let filenameEl = labelCell?.querySelector(".discovery-mountain-gems-file-label-filename");
    if (data.custom_label) {
      if (!filenameEl && labelCell) {
        filenameEl = document.createElement("span");
        filenameEl.className = "discovery-mountain-gems-file-label-filename";
        labelCell.appendChild(filenameEl);
      }
      if (filenameEl) filenameEl.textContent = data.filename;
    } else if (filenameEl) {
      filenameEl.remove();
    }

    if (this.editButton) {
      this.editButton.dataset.label = data.label || "";
    }
  }

  closeModal() {
    const modal = document.getElementById("mountainGemsFileLabel");
    const closeButton = modal?.querySelector("[data-action*='foundation-modal#close']");
    closeButton?.click();
  }

  async removeFile(event) {
    event.preventDefault();
    event.stopPropagation();

    const button = event.currentTarget;
    const deleteUrl = button.dataset.deleteUrl;
    const confirmMessage = button.dataset.confirmMessage;
    if (!deleteUrl) return;

    if (!window.confirm(confirmMessage || "Remove this file from Mountain Gems?")) return;

    button.disabled = true;

    try {
      const response = await fetch(deleteUrl, {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      });

      const data = await response.json();

      if (!response.ok || !data.ok) {
        window.alert(data.message || "Could not remove file.");
        return;
      }

      sessionStorage.setItem("mountainGemsLibraryOpen", "1");
      window.location.reload();
    } catch (error) {
      window.alert(`Remove failed: ${error.message}`);
    } finally {
      button.disabled = false;
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }
}
