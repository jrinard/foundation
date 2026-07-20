import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "status",
    "modalStatus",
    "modalMatches",
    "modalDetails",
    "modalBackButton",
    "modalConfirmButton",
    "tab",
    "panel",
    "sosMenu",
    "sosMenuButton",
    "sosDropdown",
    "placesModalHost",
    "editModalHost",
    "scoreCardHost",
    "captureSummaryHost",
    "scoreButton"
  ]

  static values = {
    googlePlacesUrl: String,
    selectGooglePlaceUrl: String,
    updateUrl: String,
    scoreUrl: String,
    scoreCardUrl: String,
    currentEnrichment: Object,
    businessSnapshot: Object
  }

  connect() {
    this.activeApi = "v1"
    this.pendingDetails = null
    this.lastSearchData = null
    this.handleModalClosed = this.handleModalClosed.bind(this)
  }

  disconnect() {
    if (this.hasPlacesModalHostTarget) {
      this.placesModalHostTarget.removeEventListener("foundation-modal:closed", this.handleModalClosed)
    }
  }

  placesModalHostTargetConnected(element) {
    element.addEventListener("foundation-modal:closed", this.handleModalClosed)
  }

  placesModalHostTargetDisconnected(element) {
    element.removeEventListener("foundation-modal:closed", this.handleModalClosed)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  get placesModal() {
    if (!this.hasPlacesModalHostTarget) return null
    return this.application.getControllerForElementAndIdentifier(this.placesModalHostTarget, "foundation-modal")
  }

  get editModal() {
    if (!this.hasEditModalHostTarget) return null
    return this.application.getControllerForElementAndIdentifier(this.editModalHostTarget, "foundation-modal")
  }

  openEditModal(event) {
    event.preventDefault()
    this.closeSosMenu()
    this.editModal?.open()
  }

  async persistScore(event) {
    event.preventDefault()

    const button = event.currentTarget
    button.disabled = true
    this.setPageStatus("Saving…")

    try {
      const response = await fetch(this.scoreUrlValue, {
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
      this.replaceCaptureSummary(data.capture_summary_html)
      this.setPageStatus(data.message, true)
    } catch (error) {
      this.setPageStatus(error.message, false)
    } finally {
      button.disabled = false
    }
  }

  async refreshScoreCard() {
    if (!this.hasScoreCardUrlValue || !this.hasScoreCardHostTarget) return

    try {
      const response = await fetch(this.scoreCardUrlValue, {
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      if (response.ok && data.score_card_html) {
        this.replaceScoreCard(data.score_card_html)
        this.replaceCaptureSummary(data.capture_summary_html)
      }
    } catch (_error) {
      // Non-blocking refresh
    }
  }

  replaceScoreCard(html) {
    if (!this.hasScoreCardHostTarget || !html) return
    this.scoreCardHostTarget.innerHTML = html
  }

  replaceCaptureSummary(html) {
    if (!this.hasCaptureSummaryHostTarget || !html) return
    this.captureSummaryHostTarget.innerHTML = html
  }

  applyBusinessSnapshot(snapshot) {
    if (!snapshot || typeof snapshot !== "object") return
    this.businessSnapshotValue = { ...this.businessSnapshotValue, ...snapshot }
    this.currentEnrichmentValue = {
      phone: snapshot.phone ?? this.currentEnrichmentValue?.phone ?? "",
      website: snapshot.website ?? this.currentEnrichmentValue?.website ?? "",
      google_place_id: snapshot.google_place_id ?? this.currentEnrichmentValue?.google_place_id ?? "",
      google_rating: snapshot.google_rating ?? this.currentEnrichmentValue?.google_rating ?? "",
      google_rating_count: snapshot.google_rating_count ?? this.currentEnrichmentValue?.google_rating_count ?? ""
    }
  }

  buildInlineUpdateFormData(edits = {}) {
    const merged = { ...this.businessSnapshotValue, ...edits }
    const body = new FormData()
    body.append("inline", "1")

    Object.entries(merged).forEach(([key, value]) => {
      body.append(`discovery_business[${key}]`, value == null ? "" : String(value))
    })

    return body
  }

  handleToggleError(event) {
    const message = event.detail?.message || "Update failed."
    this.setPageStatus(message, false)
  }

  handleInlineFieldSaved(event) {
    const detail = event.detail || {}
    if (detail.businessSnapshot) {
      this.applyBusinessSnapshot(detail.businessSnapshot)
    }
    if (detail.scoreCardHtml) {
      this.replaceScoreCard(detail.scoreCardHtml)
    } else if (detail.refreshScore) {
      this.refreshScoreCard()
    }
    if (detail.captureSummaryHtml) {
      this.replaceCaptureSummary(detail.captureSummaryHtml)
    }
    if (detail.message) {
      this.setPageStatus(detail.message, true)
    }
  }

  handleInlineFieldError(event) {
    const message = event.detail?.message || "Update failed."
    this.setPageStatus(message, false)
  }

  switchTab(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    if (!tabName) return

    this.closeSosMenu()

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tab === tabName
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.panel !== tabName
    })
  }

  toggleSosMenu(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.hasSosDropdownTarget) return

    const open = this.sosDropdownTarget.hidden
    this.sosDropdownTarget.hidden = !open
    if (this.hasSosMenuButtonTarget) {
      this.sosMenuButtonTarget.setAttribute("aria-expanded", open ? "true" : "false")
      this.sosMenuButtonTarget.classList.toggle("is-open", open)
    }
  }

  closeSosMenu() {
    if (!this.hasSosDropdownTarget) return
    this.sosDropdownTarget.hidden = true
    if (this.hasSosMenuButtonTarget) {
      this.sosMenuButtonTarget.setAttribute("aria-expanded", "false")
      this.sosMenuButtonTarget.classList.remove("is-open")
    }
  }

  closeSosMenuOnOutside(event) {
    if (!this.hasSosMenuTarget) return
    if (this.sosMenuTarget.contains(event.target)) return
    this.closeSosMenu()
  }

  async checkGooglePlaces(event) {
    event.preventDefault()

    const button = event.currentTarget
    const api = button.dataset.api || "v1"
    this.activeApi = api
    const actionButtons = this.placesActionButtons(button)
    actionButtons.forEach((el) => {
      el.disabled = true
    })

    this.pendingDetails = null
    this.lastSearchData = null
    this.showMatchesStep()
    this.setModalTitle("Google Places")
    this.setModalStatus("Searching…")
    this.setPageStatus("")
    this.clearModalPanels()
    this.placesModal?.open()

    try {
      const url = new URL(this.googlePlacesUrlValue, window.location.origin)
      url.searchParams.set("api", api)

      const response = await fetch(url.toString(), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      this.logSearchResult(data)
      this.lastSearchData = data
      this.renderMatches(data)

      const label = data.api_label || (data.api === "v1" ? "Places V1" : "Legacy")
      this.setModalTitle(`Advanced Data`)
      this.setModalStatus("")
      this.setPageStatus("")
    } catch (error) {
      console.error("[Discovery Google Places search]", error)
      this.setModalStatus(`Google Places search failed: ${error.message}`)
    } finally {
      actionButtons.forEach((el) => {
        el.disabled = false
      })
    }
  }

  placesActionButtons(button) {
    const split = button.closest(".discovery-capture-split-btn")
    if (split) return Array.from(split.querySelectorAll("button"))
    return [button]
  }

  async selectMatch(event) {
    event.preventDefault()

    const button = event.currentTarget
    const placeId = button.dataset.placeId
    const api = button.dataset.api || this.activeApi || "v1"
    if (!placeId) return

    button.disabled = true
    this.setMatchButtonsDisabled(true)
    this.setModalStatus("Loading place details…")

    try {
      const url = new URL(this.selectGooglePlaceUrlValue, window.location.origin)
      url.searchParams.set("api", api)
      url.searchParams.set("place_id", placeId)

      const response = await fetch(url.toString(), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      this.logDetailsResult(data)

      if (data.ok && data.details) {
        this.pendingDetails = data.details
        this.renderSelectedDetails(data)
        this.showDetailsStep()
        this.setModalTitle("Google Places — confirm details")
        this.setModalStatus(data.message || "")
      } else {
        this.setModalStatus(data.message || "Could not load place details.")
      }
    } catch (error) {
      console.error("[Discovery Google Places details]", error)
      this.setModalStatus(`Google Places details failed: ${error.message}`)
    } finally {
      button.disabled = false
      this.setMatchButtonsDisabled(false)
    }
  }

  backToMatches(event) {
    event?.preventDefault()
    this.pendingDetails = null
    this.showMatchesStep()
    if (this.lastSearchData) {
      this.renderMatches(this.lastSearchData)
      const label = this.lastSearchData.api_label || (this.lastSearchData.api === "v1" ? "Places V1" : "Legacy")
      this.setModalTitle(`${label} — pick a match`)
      this.setModalStatus("")
    }
  }

  async confirmPlacesSave(event) {
    event?.preventDefault()
    if (!this.pendingDetails || !this.updateUrlValue) return

    const details = this.pendingDetails
    const button = this.hasModalConfirmButtonTarget ? this.modalConfirmButtonTarget : null
    if (button) button.disabled = true
    this.setModalStatus("Saving…")

    try {
      const body = new FormData()
      const appendIfPresent = (name, value) => {
        if (value == null || value === "") return
        body.append(`discovery_business[${name}]`, String(value))
      }

      appendIfPresent("phone", details.phone)
      appendIfPresent("website", details.website)
      appendIfPresent("google_place_id", details.place_id)
      appendIfPresent("google_rating", details.rating)
      appendIfPresent("google_rating_count", details.user_ratings_total)
      body.append("discovery_business[places_check_status]", "found")
      body.append("persist_score", "1")

      if (!details.place_id) {
        this.setModalStatus("Missing place ID — cannot save.")
        return
      }

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
      if (!data.ok) {
        this.setModalStatus(data.message || "Save failed.")
        this.setPageStatus(data.message || "Save failed.", false)
        return
      }

      this.pendingDetails = null
      this.placesModal?.close()
      if (data.score_card_html) {
        this.replaceScoreCard(data.score_card_html)
        this.replaceCaptureSummary(data.capture_summary_html)
      }
      this.setPageStatus(data.message, true)
      window.location.assign(data.redirect_url || window.location.href)
    } catch (error) {
      console.error("[Discovery Google Places save]", error)
      this.setModalStatus(`Save failed: ${error.message}`)
      this.setPageStatus(`Save failed: ${error.message}`, false)
    } finally {
      if (button) button.disabled = false
    }
  }

  handleModalClosed() {
    this.pendingDetails = null
    this.clearModalPanels()
    this.showMatchesStep()
    this.setModalTitle("Google Places")
    this.setModalStatus("")
  }

  socialPlaceholder(event) {
    event.preventDefault()
    const network = event.currentTarget.dataset.network || "Social"
    console.log(`%c=== Discovery ${network} ===`, "color: #fff; font-weight: bold;")
    console.log("%cPlaceholder — lookup not implemented yet.", "color: #f5c542;")
    this.setPageStatus(`${network} lookup coming soon — use Mark missing if you confirmed it’s absent.`, null)
  }

  async markCheckMissing(event) {
    event.preventDefault()
    const field = event.currentTarget.dataset.checkField
    if (!field || !this.updateUrlValue) return

    const button = event.currentTarget
    button.disabled = true
    this.setMatchButtonsDisabled(true)

    try {
      const body = new FormData()
      body.append(`discovery_business[${field}]`, "missing")
      body.append("persist_score", "1")
      if (field === "places_check_status") {
        body.append("discovery_business[google_place_id]", "")
        body.append("discovery_business[google_rating]", "")
        body.append("discovery_business[google_rating_count]", "")
      }
      if (field === "website_check_status") {
        body.append("discovery_business[website]", "")
      }
      if (field === "facebook_check_status") {
        body.append("discovery_business[facebook_url]", "")
      }
      if (field === "linkedin_check_status") {
        body.append("discovery_business[linkedin_url]", "")
      }

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
      if (!data.ok) {
        this.setModalStatus(data.message || "Could not update check status.")
        this.setPageStatus(data.message || "Could not update check status.", false)
        return
      }

      this.pendingDetails = null
      this.placesModal?.close()
      window.location.assign(data.redirect_url || window.location.href)
    } catch (error) {
      console.error("[Discovery mark check missing]", error)
      this.setPageStatus(`Update failed: ${error.message}`, false)
    } finally {
      button.disabled = false
      this.setMatchButtonsDisabled(false)
    }
  }

  renderMatches(data) {
    if (!this.hasModalMatchesTarget) return

    const places = data.places || []
    if (!data.ok || !places.length) {
      this.modalMatchesTarget.innerHTML = `
        <p class="theme-text discovery-places-modal-empty">
          ${this.escapeHtml(data.message || "No Google Places matches found.")}
        </p>
        <div class="discovery-places-no-match-actions">
          <button type="button"
                  class="btn btn-dark discovery-page-btn theme-text"
                  data-check-field="places_check_status"
                  data-action="click->discovery-business-show#markCheckMissing">
            Confirm No Google Page
          </button>
        </div>`
      return
    }

    const rows = places
      .map((place) => {
        const name = this.escapeHtml(place.name || "Untitled place")
        const address = this.escapeHtml(place.formatted_address || "—")
        const placeId = this.escapeHtml(place.place_id || "")

        return `
          <tr class="discovery-places-match-row" data-place-id="${placeId}">
            <td class="theme-text discovery-places-match-candidate">
              <div class="discovery-places-match-name">${name}</div>
              <div class="discovery-places-match-meta">${address}</div>
            </td>
            <td class="theme-text discovery-places-match-action">
              <button type="button"
                      class="btn btn-warning discovery-page-btn theme-text discovery-places-match-btn"
                      data-action="click->discovery-business-show#selectMatch"
                      data-api="${this.escapeHtml(data.api || "v1")}"
                      data-place-id="${placeId}">
                This is the match
              </button>
            </td>
          </tr>`
      })
      .join("")

    this.modalMatchesTarget.innerHTML = `
      <p class="theme-text discovery-business-show-section-note">
        Searching for: <strong>${this.escapeHtml(data.query || "")}</strong>
      </p>
      <div class="discovery-results-table-wrap discovery-places-matches-wrap">
        <table class="discovery-results-table discovery-places-matches-table">
          <thead>
            <tr>
              <th scope="col" class="theme-text">Candidate</th>
              <th scope="col" class="theme-text discovery-places-match-action-head">Action</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
      <div class="discovery-places-no-match-actions">
        <p class="theme-text discovery-places-no-match-note">None of these look right?</p>
        <button type="button"
                class="btn btn-dark discovery-page-btn theme-text"
                data-check-field="places_check_status"
                data-action="click->discovery-business-show#markCheckMissing">
          Confirm  No Google Page
        </button>
      </div>`
  }

  renderSelectedDetails(data) {
    if (!this.hasModalDetailsTarget) return

    const details = data.details || {}
    const current = this.currentEnrichmentValue || {}
    const ratingDisplay =
      details.rating != null
        ? `${details.rating}${details.user_ratings_total != null ? ` (${details.user_ratings_total})` : ""}`
        : null
    const currentRatingDisplay = this.formatCurrentRating(current)

    const rows = [
      this.compareRow("Name", null, details.name, { alwaysNeutral: true }),
      this.compareRow("Phone", current.phone, details.phone),
      this.compareRow("Website", current.website, details.website),
      this.compareRow("Google rating", currentRatingDisplay, ratingDisplay),
      this.compareRow("Place ID", current.google_place_id, details.place_id)
    ].join("")

    this.modalDetailsTarget.innerHTML = `
      <dl class="discovery-business-detail-list discovery-places-confirm-list">${rows}</dl>`
  }

  compareRow(label, currentValue, nextValue, { alwaysNeutral = false } = {}) {
    const currentText = this.displayValue(currentValue)
    const nextText = this.displayValue(nextValue)
    const isNew =
      !alwaysNeutral &&
      this.normalizeValue(nextValue) !== "" &&
      this.normalizeValue(nextValue) !== this.normalizeValue(currentValue)
    const nextClass = isNew ? "discovery-places-value-new" : "theme-text"

    return `
      <div class="discovery-business-detail-row discovery-places-confirm-row">
        <dt class="theme-text">${this.escapeHtml(label)}</dt>
        <dd class="theme-text">
          <div class="discovery-places-compare-current">Current: ${this.escapeHtml(currentText)}</div>
          <div class="${nextClass}">New: ${this.escapeHtml(nextText)}</div>
        </dd>
      </div>`
  }

  formatCurrentRating(current) {
    if (current.google_rating == null || current.google_rating === "") return null
    const count =
      current.google_rating_count != null && current.google_rating_count !== ""
        ? ` (${current.google_rating_count})`
        : ""
    return `${current.google_rating}${count}`
  }

  displayValue(value) {
    if (value == null || value === "") return "—"
    return String(value)
  }

  normalizeValue(value) {
    return value == null ? "" : String(value).trim()
  }

  showMatchesStep() {
    if (this.hasModalMatchesTarget) this.modalMatchesTarget.hidden = false
    if (this.hasModalDetailsTarget) {
      this.modalDetailsTarget.hidden = true
      this.modalDetailsTarget.innerHTML = ""
    }
    if (this.hasModalBackButtonTarget) this.modalBackButtonTarget.hidden = true
    if (this.hasModalConfirmButtonTarget) this.modalConfirmButtonTarget.hidden = true
  }

  showDetailsStep() {
    if (this.hasModalMatchesTarget) this.modalMatchesTarget.hidden = true
    if (this.hasModalDetailsTarget) this.modalDetailsTarget.hidden = false
    if (this.hasModalBackButtonTarget) this.modalBackButtonTarget.hidden = false
    if (this.hasModalConfirmButtonTarget) this.modalConfirmButtonTarget.hidden = false
  }

  clearModalPanels() {
    if (this.hasModalMatchesTarget) this.modalMatchesTarget.innerHTML = ""
    if (this.hasModalDetailsTarget) this.modalDetailsTarget.innerHTML = ""
  }

  setModalTitle(title) {
    const el = this.element.querySelector("#discoveryGooglePlacesTitle")
    if (el) el.textContent = title
  }

  setModalStatus(message) {
    if (!this.hasModalStatusTarget) return
    this.modalStatusTarget.textContent = message || ""
  }

  setPageStatus(message, ok) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message || ""
    if (ok === true) {
      this.statusTarget.className = "theme-text discovery-sos-status discovery-sos-status-ok discovery-business-show-status"
    } else if (ok === false) {
      this.statusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error discovery-business-show-status"
    } else {
      this.statusTarget.className = "theme-text discovery-sos-status discovery-business-show-status"
    }
  }

  setMatchButtonsDisabled(disabled) {
    if (!this.hasModalMatchesTarget) return
    this.modalMatchesTarget.querySelectorAll("button").forEach((button) => {
      button.disabled = disabled
    })
  }

  logSearchResult(data) {
    const headerStyle = "color: #fff; font-weight: bold; font-size: 13px;"
    const okStyle = "color: #7dcea0; font-weight: bold;"
    const errStyle = "color: #f1948a; font-weight: bold;"
    const metaStyle = "color: #fff; font-weight: bold;"
    const bodyStyle = "color: #fff; font-family: monospace; font-size: 11px;"
    const label = data.api_label || (data.api === "v1" ? "Places V1" : "Legacy")

    console.log(`%c=== Discovery Google Places search (${label}) ===`, headerStyle)
    console.log(`%c${data.message || ""}`, data.ok ? okStyle : errStyle)
    console.log("%c--- query ---", metaStyle)
    console.log(`%c${data.query || "(empty)"}`, bodyStyle)
    console.log("%c--- matches ---", metaStyle)
    console.log(data.places || [])
  }

  logDetailsResult(data) {
    const headerStyle = "color: #fff; font-weight: bold; font-size: 13px;"
    const okStyle = "color: #7dcea0; font-weight: bold;"
    const errStyle = "color: #f1948a; font-weight: bold;"
    const metaStyle = "color: #fff; font-weight: bold;"
    const label = data.api_label || (data.api === "v1" ? "Places V1" : "Legacy")

    console.log(`%c=== Discovery Google Places details (${label}) ===`, headerStyle)
    console.log(`%c${data.message || ""}`, data.ok ? okStyle : errStyle)
    console.log("%c--- details ---", metaStyle)
    console.log(data.details || "(none)")
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
