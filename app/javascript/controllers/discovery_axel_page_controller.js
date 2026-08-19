import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "rowLimit",
    "rowRangeEnabled",
    "rowRangeStart",
    "rowRangeEnd",
    "rowRangePanel",
    "rowRangeStartLabel",
    "rowRangeEndLabel",
    "modalRowLimit",
    "modalRowRangeEnabled",
    "modalRowRangeStart",
    "modalRowRangeEnd",
    "modalRowRangeStartSlider",
    "modalRowRangeEndSlider"
  ]

  connect() {
    this.syncRowRangeLabels()
  }

  syncModalFromForm() {
    if (!this.hasModalRowLimitTarget) return

    this.modalRowLimitTarget.value = this.rowLimitTarget.value
    this.modalRowRangeEnabledTarget.checked = this.rowRangeEnabledTarget.value === "1"
    this.modalRowRangeStartTarget.value = this.rowRangeStartTarget.value
    this.modalRowRangeEndTarget.value = this.rowRangeEndTarget.value
    if (this.hasModalRowRangeStartSliderTarget) {
      this.modalRowRangeStartSliderTarget.value = this.rowRangeStartTarget.value
    }
    if (this.hasModalRowRangeEndSliderTarget) {
      this.modalRowRangeEndSliderTarget.value = this.rowRangeEndTarget.value
    }
    this.toggleRowRangePanel(this.modalRowRangeEnabledTarget.checked)
    this.syncRowRangeLabels()
  }

  applySettings(event) {
    event.preventDefault()
    this.rowLimitTarget.value = this.modalRowLimitTarget.value
    this.rowRangeEnabledTarget.value = this.modalRowRangeEnabledTarget.checked ? "1" : "0"
    this.rowRangeStartTarget.value = this.modalRowRangeStartTarget.value
    this.rowRangeEndTarget.value = this.modalRowRangeEndTarget.value
  }

  toggleRowRange(event) {
    this.toggleRowRangePanel(event.currentTarget.checked)
  }

  toggleRowRangePanel(enabled) {
    if (!this.hasRowRangePanelTarget) return
    this.rowRangePanelTarget.classList.toggle("is-hidden", !enabled)
  }

  syncRowRange() {
    let start = Number.parseInt(this.modalRowRangeStartTarget.value, 10)
    let end = Number.parseInt(this.modalRowRangeEndTarget.value, 10)
    const max = Number.parseInt(this.modalRowRangeEndTarget.max, 10) || end || 1

    start = Number.isNaN(start) ? 1 : Math.max(1, Math.min(start, max))
    end = Number.isNaN(end) ? start : Math.max(start, Math.min(end, max))

    this.modalRowRangeStartTarget.value = start
    this.modalRowRangeEndTarget.value = end
    if (this.hasModalRowRangeStartSliderTarget) this.modalRowRangeStartSliderTarget.value = start
    if (this.hasModalRowRangeEndSliderTarget) this.modalRowRangeEndSliderTarget.value = end
    this.syncRowRangeLabels()
  }

  syncRowRangeFromSlider(event) {
    const startSlider = this.modalRowRangeStartSliderTarget
    const endSlider = this.modalRowRangeEndSliderTarget
    let start = Number.parseInt(startSlider.value, 10)
    let end = Number.parseInt(endSlider.value, 10)

    if (event.currentTarget === startSlider && start > end) {
      end = start
      endSlider.value = end
    }
    if (event.currentTarget === endSlider && end < start) {
      start = end
      startSlider.value = start
    }

    this.modalRowRangeStartTarget.value = start
    this.modalRowRangeEndTarget.value = end
    this.syncRowRangeLabels()
  }

  syncRowRangeLabels() {
    if (!this.hasRowRangeStartLabelTarget || !this.hasRowRangeEndLabelTarget) return

    const start = this.hasModalRowRangeStartTarget ? this.modalRowRangeStartTarget.value : this.rowRangeStartTarget.value
    const end = this.hasModalRowRangeEndTarget ? this.modalRowRangeEndTarget.value : this.rowRangeEndTarget.value
    this.rowRangeStartLabelTarget.textContent = start
    this.rowRangeEndLabelTarget.textContent = end
  }
}
