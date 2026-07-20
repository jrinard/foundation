import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = {
    field: String,
    updateUrl: String
  }

  async update() {
    const select = this.selectTarget
    if (select.disabled) return

    const value = select.value
    select.disabled = true

    try {
      const body = new FormData()
      body.append(`discovery_business[${this.fieldValue}]`, value)

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

      this.syncVisualState(value)
      this.dispatch("saved", { detail: { ok: true, field: this.fieldValue, value } })
    } catch (error) {
      this.dispatch("error", { detail: { message: error.message } })
    } finally {
      select.disabled = false
    }
  }

  syncVisualState(value = this.selectTarget.value) {
    this.element.classList.remove("is-needs-checked", "is-na", "is-sell")
    if (value === "unchecked") {
      this.element.classList.add("is-needs-checked")
    } else if (value === "found") {
      this.element.classList.add("is-na")
    } else if (value === "missing") {
      this.element.classList.add("is-sell")
    }
  }

  connect() {
    this.syncVisualState()
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
