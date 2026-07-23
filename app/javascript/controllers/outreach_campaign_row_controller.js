import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (event.target.closest("a, button, input, select, textarea, label")) return
    window.location.assign(this.urlValue)
  }

  stop(event) {
    event.stopPropagation()
  }
}
