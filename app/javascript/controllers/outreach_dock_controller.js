import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "foundation-outreach-dock-collapsed"

export default class extends Controller {
  static targets = ["tabChevron"]
  static values = { expand: { type: Boolean, default: false } }

  connect() {
    if (this.expandValue) {
      this.collapsed = false
      this.persistCollapsedState()
    } else {
      this.collapsed = this.loadCollapsedState()
    }
    this.syncLayout()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.collapsed = !this.collapsed
    this.persistCollapsedState()
    this.syncLayout()
  }

  loadCollapsedState() {
    try {
      return localStorage.getItem(STORAGE_KEY) === "1"
    } catch (_error) {
      return false
    }
  }

  persistCollapsedState() {
    try {
      localStorage.setItem(STORAGE_KEY, this.collapsed ? "1" : "0")
    } catch (_error) {
      // ignore private browsing / blocked storage
    }
  }

  syncLayout() {
    this.element.classList.toggle("outreach-dock--collapsed", this.collapsed)
    this.element.setAttribute("aria-expanded", this.collapsed ? "false" : "true")

    if (this.hasTabChevronTarget) {
      this.tabChevronTarget.textContent = this.collapsed ? "‹" : "›"
    }
  }
}
