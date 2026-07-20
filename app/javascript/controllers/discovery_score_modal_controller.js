import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scoreCardHost", "status"]

  static values = {
    scoreUrl: String,
    scoreCardUrl: String
  }

  connect() {
    this.handleModalOpened = this.handleModalOpened.bind(this)
    this.element.addEventListener("foundation-modal:opened", this.handleModalOpened)
  }

  disconnect() {
    this.element.removeEventListener("foundation-modal:opened", this.handleModalOpened)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  handleModalOpened() {
    this.refreshScoreCard()
  }

  async persistScore(event) {
    event.preventDefault()

    const button = event.currentTarget
    button.disabled = true
    this.setStatus("Saving score…")

    try {
      const url = new URL(this.scoreUrlValue, window.location.origin)
      url.searchParams.set("modal", "1")

      const response = await fetch(url.toString(), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      if (!response.ok || !data.ok) {
        throw new Error(data.message || "Score save failed.")
      }

      this.replaceScoreCard(data.score_card_html)
      this.setStatus(data.message, true)
    } catch (error) {
      this.setStatus(error.message, false)
    } finally {
      button.disabled = false
    }
  }

  async refreshScoreCard() {
    if (!this.hasScoreCardUrlValue || !this.hasScoreCardHostTarget) return

    try {
      const url = new URL(this.scoreCardUrlValue, window.location.origin)
      url.searchParams.set("modal", "1")

      const response = await fetch(url.toString(), {
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      if (response.ok && data.score_card_html) {
        this.replaceScoreCard(data.score_card_html)
        this.setStatus("")
      }
    } catch (error) {
      this.setStatus(error.message, false)
    }
  }

  replaceScoreCard(html) {
    if (!this.hasScoreCardHostTarget || !html) return
    this.scoreCardHostTarget.innerHTML = html
  }

  setStatus(message, ok) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message || ""
    if (ok === true) {
      this.statusTarget.className = "theme-text discovery-score-modal-status discovery-sos-status-ok"
    } else if (ok === false) {
      this.statusTarget.className = "theme-text discovery-score-modal-status discovery-sos-status-error"
    } else {
      this.statusTarget.className = "theme-text discovery-score-modal-status"
    }
  }
}
