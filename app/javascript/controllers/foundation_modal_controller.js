import { Controller } from "@hotwired/stimulus"

const BODY_LOCK_CLASS = "foundation-modal-body-locked"

export default class extends Controller {
  static targets = ["backdrop", "dialog"]

  static values = {
    closeOnBackdrop: { type: Boolean, default: true },
    lockBodyScroll: { type: Boolean, default: true }
  }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.activeDialog = null
    this.activeBackdrop = null
    if (!this.isOpen) this.ensureClosed()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    this.unlockBodyScroll()
  }

  open(event) {
    event?.preventDefault()
    const pair = this.resolveModalPair(event)
    this.activeDialog = pair.dialog
    this.activeBackdrop = pair.backdrop

    pair.backdrop.hidden = false
    pair.dialog.hidden = false
    document.addEventListener("keydown", this.handleKeydown)
    this.lockBodyScroll()
    this.updateTriggerExpanded(true)
    this.dispatch("opened")
  }

  close(event) {
    event?.preventDefault()
    this.ensureClosed()
    this.dispatch("closed")
  }

  toggle(event) {
    event?.preventDefault()
    if (this.isOpen) this.close()
    else this.open(event)
  }

  backdropClick(event) {
    if (!this.closeOnBackdropValue) return
    if (this.activeBackdrop && event.currentTarget !== this.activeBackdrop) return
    this.close(event)
  }

  ensureClosed() {
    this.backdropTargets.forEach((backdrop) => {
      backdrop.hidden = true
    })
    this.dialogTargets.forEach((dialog) => {
      dialog.hidden = true
    })
    document.removeEventListener("keydown", this.handleKeydown)
    this.unlockBodyScroll()
    this.updateTriggerExpanded(false)
    this.activeDialog = null
    this.activeBackdrop = null
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  lockBodyScroll() {
    if (!this.lockBodyScrollValue) return
    document.body.classList.add(BODY_LOCK_CLASS)
  }

  unlockBodyScroll() {
    if (!this.lockBodyScrollValue) return
    document.body.classList.remove(BODY_LOCK_CLASS)
  }

  updateTriggerExpanded(open) {
    if (open) {
      const id = this.activeDialog?.id
      if (!id) return

      document.querySelectorAll(`[aria-controls="${id}"]`).forEach((el) => {
        el.setAttribute("aria-expanded", "true")
      })
      return
    }

    this.dialogTargets.forEach((dialog) => {
      document.querySelectorAll(`[aria-controls="${dialog.id}"]`).forEach((el) => {
        el.setAttribute("aria-expanded", "false")
      })
    })
  }

  resolveModalPair(event) {
    const modalId = event?.currentTarget?.getAttribute("aria-controls")
    if (modalId) {
      const dialog = this.element.querySelector(`#${CSS.escape(modalId)}`)
      if (dialog && this.dialogTargets.includes(dialog)) {
        const backdrop = dialog.previousElementSibling
        if (backdrop && this.backdropTargets.includes(backdrop)) {
          return { backdrop, dialog }
        }
      }
    }

    return { backdrop: this.backdropTarget, dialog: this.dialogTarget }
  }

  get isOpen() {
    return this.dialogTargets.some((dialog) => !dialog.hidden)
  }
}
