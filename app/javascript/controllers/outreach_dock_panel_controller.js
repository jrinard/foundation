import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["outreachPane", "scorePane", "outreachTab", "scoreTab"]

  connect() {
    this.showOutreach()
  }

  showOutreach(event) {
    event?.preventDefault()
    this.setActiveTab("outreach")
  }

  showScore(event) {
    event?.preventDefault()
    this.setActiveTab("score")
  }

  setActiveTab(tab) {
    const outreachActive = tab === "outreach"

    if (this.hasOutreachPaneTarget) {
      this.outreachPaneTarget.hidden = !outreachActive
    }
    if (this.hasScorePaneTarget) {
      this.scorePaneTarget.hidden = outreachActive
    }
    if (this.hasOutreachTabTarget) {
      this.outreachTabTarget.classList.toggle("active", outreachActive)
    }
    if (this.hasScoreTabTarget) {
      this.scoreTabTarget.classList.toggle("active", !outreachActive)
    }
  }
}
