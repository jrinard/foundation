import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "viewMode",
    "editMode",
    "display",
    "input",
    "ratingCountInput",
    "checkSelect",
    "checkIndicator",
    "saveButton"
  ]

  static values = {
    updateUrl: String,
    param: String,
    inputType: { type: String, default: "text" },
    checkParam: String,
    refreshScore: { type: Boolean, default: false },
    emptyDisplay: { type: String, default: "—" }
  }

  connect() {
    this.snapshotValues()
  }

  startEdit(event) {
    event.preventDefault()
    event.stopPropagation()
    this.snapshotValues()
    this.element.classList.add("is-editing")
    this.inputTarget.focus()
    if (this.inputTarget.select) {
      this.inputTarget.select()
    }
  }

  cancelEdit(event) {
    if (event) event.preventDefault()
    this.restoreValues()
    this.showViewMode()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancelEdit()
      return
    }

    if (event.key !== "Enter" || event.shiftKey) return
    if (event.target.tagName === "SELECT") return

    event.preventDefault()
    this.save(event)
  }

  async save(event) {
    if (event) event.preventDefault()
    if (this.hasSaveButtonTarget) this.saveButtonTarget.disabled = true

    const showController = this.showController
    if (!showController) {
      this.dispatch("error", { bubbles: true, detail: { message: "Could not save — page controller missing." } })
      if (this.hasSaveButtonTarget) this.saveButtonTarget.disabled = false
      return
    }

    try {
      const edits = this.inlineEdits()
      const body = showController.buildInlineUpdateFormData(edits)

      if (this.shouldPersistScore()) {
        body.append("persist_score", "1")
      }

      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body,
        credentials: "same-origin"
      })

      const data = await response.json()
      if (!response.ok || !data.ok) {
        throw new Error(data.message || "Update failed.")
      }

      if (data.business_snapshot) {
        showController.applyBusinessSnapshot(data.business_snapshot)
      } else {
        showController.applyBusinessSnapshot(edits)
      }

      this.snapshotValues()
      this.updateDisplay()
      this.updateVerifiedIndicator()
      this.showViewMode()

      const savedDetail = {
        message: data.message,
        businessSnapshot: data.business_snapshot
      }

      if (data.score_card_html) {
        savedDetail.scoreCardHtml = data.score_card_html
      } else if (this.shouldPersistScore()) {
        savedDetail.refreshScore = true
      }

      if (data.capture_summary_html) {
        savedDetail.captureSummaryHtml = data.capture_summary_html
      }

      this.dispatch("saved", { bubbles: true, detail: savedDetail })
    } catch (error) {
      this.dispatch("error", { bubbles: true, detail: { message: error.message } })
    } finally {
      if (this.hasSaveButtonTarget) this.saveButtonTarget.disabled = false
    }
  }

  inlineEdits() {
    const edits = { [this.paramValue]: this.currentInputValue() }

    if (this.inputTypeValue === "google_rating" && this.hasRatingCountInputTarget) {
      edits.google_rating_count = this.ratingCountInputTarget.value.trim()
    }

    if (this.hasCheckSelectTarget && this.checkParamValue) {
      edits[this.checkParamValue] = this.checkSelectTarget.value
    }

    return edits
  }

  shouldPersistScore() {
    return this.refreshScoreValue || (this.hasCheckSelectTarget && this.checkParamValue)
  }

  get showController() {
    const host = this.element.closest('[data-controller~="discovery-business-show"]')
    if (!host) return null
    return this.application.getControllerForElementAndIdentifier(host, "discovery-business-show")
  }

  showViewMode() {
    this.element.classList.remove("is-editing")
  }

  snapshotValues() {
    this.originalValue = this.currentInputValue()
    this.originalRatingCount = this.hasRatingCountInputTarget ? this.ratingCountInputTarget.value : null
    this.originalCheckStatus = this.hasCheckSelectTarget ? this.checkSelectTarget.value : null
  }

  restoreValues() {
    this.inputTarget.value = this.originalValue ?? ""
    if (this.hasRatingCountInputTarget) {
      this.ratingCountInputTarget.value = this.originalRatingCount ?? ""
    }
    if (this.hasCheckSelectTarget) {
      this.checkSelectTarget.value = this.originalCheckStatus ?? "unchecked"
    }
  }

  currentInputValue() {
    return this.inputTarget.value.trim()
  }

  updateDisplay() {
    const value = this.currentInputValue()

    if (this.inputTypeValue === "url") {
      if (value) {
        this.displayTarget.innerHTML = `<a href="${this.escapeAttr(value)}" class="theme-text" target="_blank" rel="noopener">${this.escapeHtml(value)}</a>`
      } else {
        this.displayTarget.textContent = this.emptyDisplayValue
      }
      return
    }

    if (this.inputTypeValue === "google_rating") {
      const count = this.hasRatingCountInputTarget ? this.ratingCountInputTarget.value.trim() : ""
      if (!value) {
        this.displayTarget.textContent = this.emptyDisplayValue
        return
      }
      this.displayTarget.textContent = count ? `${value} (${count})` : value
      return
    }

    this.displayTarget.textContent = value || this.emptyDisplayValue
  }

  updateVerifiedIndicator() {
    if (!this.hasCheckIndicatorTarget) return

    const value = this.currentInputValue()
    const checkStatus = this.hasCheckSelectTarget ? this.checkSelectTarget.value : null
    let verified = false

    switch (this.paramValue) {
      case "website":
      case "facebook_url":
      case "linkedin_url":
      case "instagram_url":
        verified = !!value || checkStatus === "missing"
        break
      case "google_rating":
        verified = !!value
        break
      default:
        verified = !!value
    }

    this.checkIndicatorTarget.classList.toggle("is-verified", verified)
    this.checkIndicatorTarget.title = verified ? "Verified on file" : "Not checked yet"
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  escapeAttr(value) {
    return this.escapeHtml(value).replace(/'/g, "&#39;")
  }
}
