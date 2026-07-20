import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track"]
  static values = {
    checked: Boolean,
    field: String,
    updateUrl: String,
    onValue: { type: String, default: "missing" },
    offValue: { type: String, default: "found" }
  }

  async toggle(event) {
    event.preventDefault()
    if (this.trackTarget.disabled) return

    const nextChecked = !this.checkedValue
    this.trackTarget.disabled = true

    try {
      const body = new FormData()
      body.append(`discovery_business[${this.fieldValue}]`, nextChecked ? this.onValueValue : this.offValueValue)

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

      this.checkedValue = nextChecked
      this.syncVisualState()
      this.dispatch("saved", { detail: { ok: true, field: this.fieldValue, value: nextChecked ? this.onValueValue : this.offValueValue } })
    } catch (error) {
      this.dispatch("error", { detail: { message: error.message } })
    } finally {
      this.trackTarget.disabled = false
    }
  }

  checkedValueChanged() {
    this.syncVisualState()
  }

  syncVisualState() {
    this.element.classList.toggle("is-on", this.checkedValue)
    this.trackTarget.setAttribute("aria-checked", this.checkedValue ? "true" : "false")
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
