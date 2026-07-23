import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "row", "noResults"]

  connect() {
    this.handleModalOpened = this.handleModalOpened.bind(this)
    this.element.addEventListener("foundation-modal:opened", this.handleModalOpened)
    this.filter()
  }

  disconnect() {
    this.element.removeEventListener("foundation-modal:opened", this.handleModalOpened)
  }

  handleModalOpened() {
    if (!this.hasQueryTarget) return

    this.queryTarget.value = ""
    this.filter()
    this.queryTarget.focus()
  }

  filter() {
    if (!this.hasQueryTarget) return

    const term = this.queryTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const haystack = row.dataset.filterText || ""
      const match = term === "" || haystack.includes(term)
      row.hidden = !match
      if (match) visibleCount += 1
    })

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.hidden = visibleCount > 0
    }
  }
}
