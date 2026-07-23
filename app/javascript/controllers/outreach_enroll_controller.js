import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["planSelect", "campaignSelect"]

  connect() {
    this.filterCampaigns()
  }

  filterCampaigns() {
    if (!this.hasPlanSelectTarget || !this.hasCampaignSelectTarget) return

    const planId = this.planSelectTarget.value
    const options = Array.from(this.campaignSelectTarget.options)

    options.forEach((option) => {
      if (!option.value) {
        option.hidden = false
        return
      }

      const matches = !planId || option.dataset.planId === planId
      option.hidden = !matches
      if (!matches && option.selected) option.selected = false
    })

    const visible = options.filter((option) => !option.hidden && option.value)
    if (visible.length === 1) visible[0].selected = true
  }
}
