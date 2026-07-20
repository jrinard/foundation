import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "businessTypeId",
    "startDate",
    "endDate",
    "dateCadence",
    "modalBusinessTypeId",
    "modalStartDate",
    "modalEndDate",
    "defaultsBusinessTypeId",
    "defaultsDateCadence",
    "cadenceButton"
  ]

  connect() {
    this.highlightCadence(this.currentCadence())
  }

  syncModalFromForm() {
    if (!this.hasModalBusinessTypeIdTarget) return

    this.modalBusinessTypeIdTarget.value = this.businessTypeIdTarget.value
    this.modalStartDateTarget.value = this.startDateTarget.value
    this.modalEndDateTarget.value = this.endDateTarget.value
    this.highlightCadence(this.currentCadence())
  }

  applySettings(event) {
    event.preventDefault()
    this.syncFormFromModal()
  }

  syncDefaultsBeforeSave() {
    this.defaultsBusinessTypeIdTarget.value = this.modalBusinessTypeIdTarget.value
    if (this.hasDefaultsDateCadenceTarget) {
      this.defaultsDateCadenceTarget.value = this.selectedCadence()
    }
  }

  syncFormFromModal() {
    this.businessTypeIdTarget.value = this.modalBusinessTypeIdTarget.value
    this.startDateTarget.value = this.modalStartDateTarget.value
    this.endDateTarget.value = this.modalEndDateTarget.value
    if (this.hasDateCadenceTarget) {
      this.dateCadenceTarget.value = this.selectedCadence()
    }
  }

  setCadence(event) {
    event.preventDefault()
    const cadence = event.params.cadence
    const range = this.dateRangeForCadence(cadence)

    this.modalStartDateTarget.value = range.start
    this.modalEndDateTarget.value = range.end
    this.highlightCadence(cadence)
  }

  highlightCadence(cadence) {
    this.cadenceButtonTargets.forEach((button) => {
      const active = button.dataset.discoverySosPageCadenceParam === cadence
      button.classList.toggle("discovery-cadence-active", active)
    })
  }

  selectedCadence() {
    const active = this.cadenceButtonTargets.find((button) =>
      button.classList.contains("discovery-cadence-active")
    )
    return active?.dataset.discoverySosPageCadenceParam || this.currentCadence()
  }

  currentCadence() {
    return this.dateCadenceTarget?.value || "24h"
  }

  dateRangeForCadence(cadence) {
    const end = new Date()
    const start = new Date(end)

    switch (cadence) {
      case "1week":
        start.setDate(start.getDate() - 7)
        break
      case "1month":
        start.setMonth(start.getMonth() - 1)
        break
      default:
        start.setTime(end.getTime() - 24 * 60 * 60 * 1000)
    }

    return {
      start: this.formatDate(start),
      end: this.formatDate(end)
    }
  }

  formatDate(date) {
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    const year = date.getFullYear()
    return `${month}/${day}/${year}`
  }
}
