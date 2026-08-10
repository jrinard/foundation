import { Controller } from "@hotwired/stimulus"
import { applyFunnelFilters } from "../discovery/wa_sos_funnel_filters"

const SKIPPED_UBIS_STORAGE_KEY = "foundation_discovery_sos_skipped_ubis"

export default class extends Controller {
  static targets = [
    "status",
    "results",
    "resultsPanel",
    "resultsToggle",
    "cityFilter",
    "nameFilter",
    "filterDefaultsCity",
    "saveStatus",
    "captured",
    "capturedTitle",
    "capturedTitleLabel",
    "capturedCount",
    "hideArchived",
    "hideArchivedLabel",
    "archiveFilter",
    "archiveFilterWrap",
    "archivedViewBtn",
    "runs",
    "editForm",
    "editBusinessName",
    "editSosBusinessId",
    "editPhone",
    "editEmail",
    "editGooglePlaceId",
    "businessSearchInput",
    "businessSearchSubmit"
  ]

  static values = {
    columns: Array,
    saveUrl: String,
    fetchUrl: String,
    capturedListUrl: String,
    capturedView: { type: String, default: "working" },
    hideArchived: { type: Boolean, default: true },
    archiveFilter: { type: String, default: "all" }
  }

  connect() {
    this.allRows = []
    this.filteredRows = []
    this.editUpdateUrl = null
    this.businessNameSearchMode = false
    this.skippedUbis = this.loadSkippedUbis()
    this.syncCapturedControls()
  }

  openCapturedEdit(event) {
    const button = event.currentTarget

    this.editUpdateUrl = button.dataset.updateUrl

    if (this.hasEditBusinessNameTarget) {
      this.editBusinessNameTarget.textContent = button.dataset.businessName || ""
    }
    if (this.hasEditSosBusinessIdTarget) {
      this.editSosBusinessIdTarget.value = button.dataset.sosBusinessId || ""
    }
    if (this.hasEditPhoneTarget) {
      this.editPhoneTarget.value = button.dataset.phone || ""
    }
    if (this.hasEditEmailTarget) {
      this.editEmailTarget.value = button.dataset.email || ""
    }
    if (this.hasEditGooglePlaceIdTarget) {
      this.editGooglePlaceIdTarget.value = button.dataset.googlePlaceId || ""
    }
  }

  async submitCapturedEdit(event) {
    event.preventDefault()

    if (!this.editUpdateUrl || !this.hasEditFormTarget) return

    const form = this.editFormTarget
    const submitButton = form.querySelector('[type="submit"]')
    if (submitButton) submitButton.disabled = true

    try {
      const response = await fetch(this.editUpdateUrl, {
        method: "PATCH",
        body: new FormData(form),
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()

      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = data.message || ""
        this.saveStatusTarget.className = data.ok
          ? "theme-text discovery-sos-status discovery-sos-status-ok"
          : "theme-text discovery-sos-status discovery-sos-status-error"
      }

      if (data.ok && this.hasCapturedTarget && data.captured_html) {
        this.capturedTarget.innerHTML = data.captured_html
        this.syncCapturedCountFromDom()
        this.closeEditModal()
      }
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = `Update failed: ${error.message}`
        this.saveStatusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error"
      }
    } finally {
      if (submitButton) submitButton.disabled = false
    }
  }

  closeEditModal() {
    const modal = document.getElementById("discoveryCapturedBusinessEdit")
    const closeButton = modal?.querySelector("[data-action*='foundation-modal#close']")
    closeButton?.click()
  }

  async promoteToPotential(event) {
    event.preventDefault()

    const button = event.currentTarget
    const promoteUrl = button.dataset.promoteUrl
    if (!promoteUrl) return

    const businessName = button.dataset.businessName || "this business"
    if (!window.confirm(`Move "${businessName}" to Potentials?`)) return

    button.disabled = true

    try {
      const response = await fetch(this.withCapturedListParams(promoteUrl), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()

      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = data.message || ""
        this.saveStatusTarget.className = data.ok
          ? "theme-text discovery-sos-status discovery-sos-status-ok"
          : "theme-text discovery-sos-status discovery-sos-status-error"
      }

      if (data.ok && this.hasCapturedTarget && data.captured_html) {
        this.capturedTarget.innerHTML = data.captured_html
        this.syncCapturedCountFromDom()
      }
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = `Promote failed: ${error.message}`
        this.saveStatusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error"
      }
    } finally {
      button.disabled = false
    }
  }

  toggleArchivedView() {
    this.capturedViewValue = this.capturedViewValue === "archived" ? "working" : "archived"
    this.syncCapturedControls()
    this.refreshCapturedList()
  }

  async refreshCapturedList() {
    if (!this.capturedListUrlValue || !this.hasCapturedTarget) return

    if (this.hasHideArchivedTarget) {
      this.hideArchivedValue = this.hideArchivedTarget.checked
    }
    if (this.hasArchiveFilterTarget) {
      this.archiveFilterValue = this.archiveFilterTarget.value || "all"
    }

    try {
      const response = await fetch(this.withCapturedListParams(this.capturedListUrlValue), {
        method: "GET",
        headers: {
          Accept: "text/html",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.capturedTarget.innerHTML = await response.text()
      this.syncCapturedCountFromDom()
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = `Could not refresh list: ${error.message}`
        this.saveStatusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error"
      }
    }
  }

  async archiveBusiness(event) {
    event.preventDefault()
    const button = event.currentTarget
    const url = button.dataset.archiveUrl
    if (!url) return

    const businessName = button.dataset.businessName || "this business"
    if (!window.confirm(`Archive "${businessName}"? It will leave the working Captured list.`)) return

    await this.postCapturedAction(url, button, "Archive failed")
  }

  async unarchiveBusiness(event) {
    event.preventDefault()
    const button = event.currentTarget
    const url = button.dataset.unarchiveUrl
    if (!url) return

    await this.postCapturedAction(url, button, "Unarchive failed")
  }

  skipResultRow(event) {
    event.preventDefault()

    const ubi = event.currentTarget.dataset.rowUbi
    if (!ubi) return

    this.skippedUbis.add(ubi)
    this.persistSkippedUbis()
    this.renderFilteredResults()
  }

  unskipResultRow(event) {
    event.preventDefault()

    const ubi = event.currentTarget.dataset.rowUbi
    if (!ubi) return

    this.skippedUbis.delete(ubi)
    this.persistSkippedUbis()
    this.renderFilteredResults()
  }

  loadSkippedUbis() {
    try {
      const raw = window.sessionStorage.getItem(SKIPPED_UBIS_STORAGE_KEY)
      const parsed = raw ? JSON.parse(raw) : []
      return new Set(Array.isArray(parsed) ? parsed.map((id) => String(id)) : [])
    } catch (_error) {
      return new Set()
    }
  }

  persistSkippedUbis() {
    try {
      window.sessionStorage.setItem(
        SKIPPED_UBIS_STORAGE_KEY,
        JSON.stringify(Array.from(this.skippedUbis))
      )
    } catch (_error) {
      // Non-blocking — skip state is session-only
    }
  }

  isRowSkipped(row) {
    const ubi = this.rowExternalId(row)
    return ubi !== "" && this.skippedUbis.has(ubi)
  }

  sortRowsWithSkippedLast(rows) {
    const active = []
    const skipped = []

    rows.forEach((row) => {
      if (this.isRowSkipped(row)) {
        skipped.push(row)
      } else {
        active.push(row)
      }
    })

    return [...active, ...skipped]
  }

  async postCapturedAction(url, button, errorPrefix) {
    button.disabled = true

    try {
      const response = await fetch(this.withCapturedListParams(url), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()

      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = data.message || ""
        this.saveStatusTarget.className = data.ok
          ? "theme-text discovery-sos-status discovery-sos-status-ok"
          : "theme-text discovery-sos-status discovery-sos-status-error"
      }

      if (data.ok && this.hasCapturedTarget && data.captured_html) {
        this.capturedTarget.innerHTML = data.captured_html
        this.syncCapturedCountFromDom()
      }
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = `${errorPrefix}: ${error.message}`
        this.saveStatusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error"
      }
    } finally {
      button.disabled = false
    }
  }

  syncCapturedControls() {
    const archived = this.capturedViewValue === "archived"

    if (this.hasCapturedTitleLabelTarget) {
      this.capturedTitleLabelTarget.textContent = archived ? "Archived Businesses" : "Captured Businesses"
    }
    if (this.hasHideArchivedLabelTarget) {
      this.hideArchivedLabelTarget.classList.toggle("is-hidden", archived)
    }
    if (this.hasArchiveFilterWrapTarget) {
      this.archiveFilterWrapTarget.classList.toggle("is-hidden", !archived)
    }
    if (this.hasArchivedViewBtnTarget) {
      this.archivedViewBtnTarget.textContent = archived ? "Captured List" : "View Archive"
      this.archivedViewBtnTarget.dataset.capturedView = this.capturedViewValue
    }
  }

  syncCapturedCountFromDom() {
    if (!this.hasCapturedCountTarget || !this.hasCapturedTarget) return

    const list = this.capturedTarget.querySelector("[data-captured-count]")
    const count = list ? Number.parseInt(list.dataset.capturedCount, 10) : 0
    this.capturedCountTarget.textContent = `(${Number.isNaN(count) ? 0 : count})`
  }

  withCapturedListParams(url) {
    const next = new URL(url, window.location.origin)
    next.searchParams.set("captured_view", this.capturedViewValue || "working")
    next.searchParams.set("hide_archived", this.hideArchivedValue ? "1" : "0")
    next.searchParams.set("archive_filter", this.archiveFilterValue || "all")
    return next.toString()
  }

  capturedListParams() {
    return {
      captured_view: this.capturedViewValue || "working",
      hide_archived: this.hideArchivedValue ? "1" : "0",
      archive_filter: this.archiveFilterValue || "all"
    }
  }

  async submit(event) {
    event.preventDefault()
    this.businessNameSearchMode = false
    await this.runFetch(this.collectStateFormData())
  }

  handleBusinessSearchKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    event.preventDefault()
    this.submitBusinessSearch(event)
  }

  async submitBusinessSearch(event) {
    if (event) event.preventDefault()

    const name = this.businessSearchInputTarget?.value?.trim()
    if (!name) return

    const body = this.collectStateFormData()
    body.append("search_entity_name", name)

    if (this.hasBusinessSearchSubmitTarget) {
      this.businessSearchSubmitTarget.disabled = true
    }

    try {
      this.businessNameSearchMode = true
      await this.runFetch(body, { searchName: name })
      this.closeBusinessSearchModal()
    } finally {
      if (this.hasBusinessSearchSubmitTarget) {
        this.businessSearchSubmitTarget.disabled = false
      }
    }
  }

  collectStateFormData() {
    const body = new FormData()
    const form = document.querySelector(".discovery-sos-fetch-form")
    if (!form) return body

    ;["business_type_id", "start_date", "end_date", "date_cadence"].forEach((fieldName) => {
      const field = form.querySelector(`[name="${fieldName}"]`)
      if (field) body.append(fieldName, field.value)
    })

    return body
  }

  async runFetch(body, { searchName = null } = {}) {
    const submitButton = document.querySelector(".discovery-sos-fetch-form [type='submit']")
    if (submitButton) submitButton.disabled = true

    try {
      const response = await fetch(this.fetchUrlValue, {
        method: "POST",
        body,
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      this.logResult(data)

      if (this.hasStatusTarget) {
        this.statusTarget.textContent = data.message || ""
        this.setStatusClass(data.ok)
      }

      if (data.ok) {
        this.allRows = data.all_rows || []
        if (data.business_name_search) {
          this.businessNameSearchMode = true
          if (this.hasNameFilterTarget) {
            this.nameFilterTarget.value = searchName || data.search_entity_name || ""
          }
        } else {
          this.businessNameSearchMode = false
        }
        this.expandResults()
        this.renderFilteredResults()
        this.scrollToResults()
      }

      if (data.runs_html && this.hasRunsTarget) {
        this.runsTarget.innerHTML = data.runs_html
      }
    } catch (error) {
      this.logError(error)
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Request failed: ${error.message}`
        this.setStatusClass(false)
      }
    } finally {
      if (submitButton) submitButton.disabled = false
    }
  }

  closeBusinessSearchModal() {
    const modal = document.getElementById("discoveryBusinessSearch")
    const closeButton = modal?.querySelector("[data-action*='foundation-modal#close']")
    closeButton?.click()
  }

  applyCityFilter() {
    if (!this.allRows.length) return
    this.applyFilters()
  }

  applyFilters() {
    this.renderFilteredResults()
  }

  toggleResults() {
    if (!this.hasResultsPanelTarget) return

    const collapsed = this.resultsPanelTarget.classList.toggle("is-collapsed")
    if (this.hasResultsToggleTarget) {
      this.resultsToggleTarget.classList.toggle("is-collapsed", collapsed)
      this.resultsToggleTarget.setAttribute("aria-expanded", collapsed ? "false" : "true")
    }
  }

  expandResults() {
    if (!this.hasResultsPanelTarget) return

    this.resultsPanelTarget.classList.remove("is-collapsed")
    if (this.hasResultsToggleTarget) {
      this.resultsToggleTarget.classList.remove("is-collapsed")
      this.resultsToggleTarget.setAttribute("aria-expanded", "true")
    }
  }

  setStatusClass(ok) {
    if (!this.hasStatusTarget) return

    this.statusTarget.className = ok
      ? "theme-text discovery-sos-status discovery-sos-status-under-runs discovery-sos-status-ok"
      : "theme-text discovery-sos-status discovery-sos-status-under-runs discovery-sos-status-error"
  }

  async loadRun(event) {
    event.preventDefault()

    const button = event.currentTarget
    const loadUrl = button.dataset.loadRunUrl
    if (!loadUrl) return

    button.disabled = true

    try {
      const response = await fetch(loadUrl, {
        method: "GET",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin"
      })

      const data = await response.json()

      if (this.hasStatusTarget) {
        this.statusTarget.textContent = data.message || ""
        this.setStatusClass(data.ok)
      }

      if (data.ok) {
        this.allRows = data.all_rows || []
        this.businessNameSearchMode = false
        if (this.hasNameFilterTarget) {
          this.nameFilterTarget.value = ""
        }
        if (data.filter_city && this.hasCityFilterTarget) {
          this.cityFilterTarget.value = data.filter_city
        }
        this.expandResults()
        this.renderFilteredResults()
        this.closeRunsModal()
        this.scrollToResults()
      }
    } catch (error) {
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Load failed: ${error.message}`
        this.setStatusClass(false)
      }
    } finally {
      button.disabled = false
    }
  }

  closeRunsModal() {
    const modal = document.getElementById("discoveryRuns")
    const closeButton = modal?.querySelector("[data-action*='foundation-modal#close']")
    closeButton?.click()
  }

  scrollToResults() {
    document.querySelector(".discovery-results-wrap")?.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  syncFilterDefaultBeforeSave() {
    if (this.hasFilterDefaultsCityTarget && this.hasCityFilterTarget) {
      this.filterDefaultsCityTarget.value = this.cityFilterTarget.value
    }
  }

  async saveBusinesses(event) {
    event.preventDefault()
    const rows = this.filteredRows.filter((row) => !this.isRowSkipped(row))
    if (!rows.length) return
    await this.persistRows(rows, event.currentTarget)
  }

  async captureBusiness(event) {
    event.preventDefault()

    const index = Number.parseInt(event.currentTarget.dataset.rowIndex, 10)
    const row = this.filteredRows[index]
    if (!row) return

    await this.persistRows([row], event.currentTarget)
  }

  async persistRows(rows, button) {
    if (!rows.length) return

    if (button) button.disabled = true

    try {
      const response = await fetch(this.saveUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        credentials: "same-origin",
        body: JSON.stringify({
          filter_city: this.currentCity(),
          rows,
          ...this.capturedListParams()
        })
      })

      const data = await response.json()

      if (data.ok) {
        const createdIds = new Set((data.created_external_ids || []).map((id) => String(id)))
        const rowsToRemove =
          createdIds.size > 0
            ? rows.filter((row) => createdIds.has(this.rowExternalId(row)))
            : data.created > 0
              ? rows
              : []

        if (rowsToRemove.length) {
          this.removeRowsFromResults(rowsToRemove)
          this.renderFilteredResults()
        }

        if (this.hasCapturedTarget && data.captured_html && data.created > 0) {
          this.capturedTarget.innerHTML = data.captured_html
          this.syncCapturedCountFromDom()
        }

        this.showCaptureStatus(data.message, data.created > 0 || !data.skip_messages?.length)
      } else {
        this.showCaptureStatus(data.message || "Capture failed.", false)
      }
    } catch (error) {
      if (this.hasSaveStatusTarget) {
        this.saveStatusTarget.textContent = `Capture failed: ${error.message}`
        this.saveStatusTarget.className = "theme-text discovery-sos-status discovery-sos-status-error"
      }
    } finally {
      if (button) button.disabled = false
    }
  }

  removeRowsFromResults(rows) {
    const keys = new Set(rows.map((row) => this.rowKey(row)).filter(Boolean))
    if (!keys.size) return

    rows.forEach((row) => {
      const ubi = this.rowExternalId(row)
      if (ubi) this.skippedUbis.delete(ubi)
    })
    this.persistSkippedUbis()

    this.allRows = this.allRows.filter((row) => !keys.has(this.rowKey(row)))
    this.filteredRows = this.filteredRows.filter((row) => !keys.has(this.rowKey(row)))
  }

  rowKey(row) {
    return String(row["UBI#"] || row["Business Name"] || "").trim()
  }

  rowExternalId(row) {
    return String(row["UBI#"] || "").replace(/\D/g, "")
  }

  showCaptureStatus(message, ok = true) {
    const text = message || ""
    const className = ok
      ? "theme-text discovery-sos-status discovery-sos-status-ok"
      : "theme-text discovery-sos-status discovery-sos-status-error"

    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = text
      this.saveStatusTarget.className = className
    }

    if (this.hasStatusTarget && text) {
      this.statusTarget.textContent = text
      this.setStatusClass(ok)
    }
  }

  renderFilteredResults() {
    if (!this.hasResultsTarget) return

    const filters = this.currentFilters()
    const filtered = applyFunnelFilters(this.allRows, filters)
    this.filteredRows = this.sortRowsWithSkippedLast(filtered)
    this.resultsTarget.innerHTML = this.buildResultsHtml(this.filteredRows, filters, this.allRows.length)
  }

  buildResultsHtml(rows, filters, totalUnfiltered) {
    const city = filters.city
    const nameQuery = (filters.businessName || "").trim()
    const nameSearchMode = this.businessNameSearchMode
    const skippedCount = rows.filter((row) => this.isRowSkipped(row)).length
    const activeCount = rows.length - skippedCount

    if (!rows.length) {
      if (totalUnfiltered > 0) {
        if (nameSearchMode && nameQuery) {
          return `<p class="discovery-results-empty theme-text">No businesses matching <strong>${this.escapeHtml(nameQuery)}</strong> (${totalUnfiltered} from SOS).</p>`
        }

        const parts = [`No businesses in <strong>${this.escapeHtml(city)}</strong>`]
        if (nameQuery) {
          parts.push(` matching <strong>${this.escapeHtml(nameQuery)}</strong>`)
        }
        parts.push(` (${totalUnfiltered} from Collect State).`)
        return `<p class="discovery-results-empty theme-text">${parts.join("")}</p>`
      }

      return `<p class="discovery-results-empty theme-text">No businesses returned for this search.</p>`
    }

    const cityOnlyCount = nameSearchMode
      ? totalUnfiltered
      : applyFunnelFilters(this.allRows, { city, businessName: "" }).length
    const filterNote =
      !nameSearchMode && cityOnlyCount > rows.length
        ? ` <span class="discovery-results-filter-note">(${cityOnlyCount} in city${nameQuery ? " before name filter" : ""})</span>`
        : !nameSearchMode && totalUnfiltered > cityOnlyCount
          ? ` <span class="discovery-results-filter-note">(${totalUnfiltered} from Collect State)</span>`
          : nameSearchMode && nameQuery && totalUnfiltered > rows.length
            ? ` <span class="discovery-results-filter-note">(${totalUnfiltered} from SOS before name filter)</span>`
            : ""

    const countLabel = rows.length === 1 ? "business" : "businesses"
    const captureLabel = activeCount === 1 ? "Capture 1 business" : `Capture ${activeCount} businesses`
    const skippedNote =
      skippedCount > 0
        ? ` <span class="discovery-results-filter-note">(${activeCount} active · ${skippedCount} skipped)</span>`
        : ""
    const nameMatchNote = nameQuery
      ? ` matching <strong>${this.escapeHtml(nameQuery)}</strong>`
      : ""
    const locationLabel = nameSearchMode
      ? "statewide"
      : `<strong>${this.escapeHtml(city)}</strong>`
    const header = `
      <div class="discovery-results-toolbar">
        <p class="discovery-results-count theme-text">${rows.length} ${countLabel} in ${locationLabel}${nameMatchNote}${filterNote}${skippedNote}</p>
        <button type="button" class="btn btn-sm discovery-capture-btn" data-action="click->discovery-sos-fetch#saveBusinesses"${activeCount === 0 ? " disabled" : ""}>${this.escapeHtml(captureLabel)}</button>
      </div>`

    const displayRows = this.sortRowsWithSkippedLast(rows)

    const columns = this.columnsValue
    const thead = [
      ...columns.map((column) => {
        const officeClass = column === "Office Address" ? " discovery-results-office-address" : ""
        return `<th scope="col" class="theme-text${officeClass}">${this.escapeHtml(column)}</th>`
      }),
      `<th scope="col" class="theme-text discovery-results-actions-col">Actions</th>`
    ].join("")

    const tbody = displayRows
      .map((row) => {
        const rowIndex = rows.indexOf(row)
        const skipped = this.isRowSkipped(row)
        const rowUbi = this.rowExternalId(row)
        const cells = columns
          .map((column) => {
            const officeClass = column === "Office Address" ? " discovery-results-office-address" : ""
            return `<td class="theme-text${officeClass}">${this.escapeHtml(row[column] || "—")}</td>`
          })
          .join("")
        const captureCell = `
          <td class="theme-text discovery-results-actions">
            <div class="discovery-results-action-group">
              <button type="button"
                      class="btn btn-sm discovery-capture-row-btn"
                      data-action="click->discovery-sos-fetch#captureBusiness"
                      data-row-index="${rowIndex}"
                      ${skipped ? "disabled" : ""}>
                Capture
              </button>
              ${
                skipped
                  ? `<button type="button"
                            class="btn btn-default btn-sm theme-text discovery-result-unskip-btn"
                            data-action="click->discovery-sos-fetch#unskipResultRow"
                            data-row-ubi="${this.escapeHtml(rowUbi)}">
                      Unskip
                    </button>`
                  : `<button type="button"
                            class="btn btn-default btn-sm theme-text discovery-result-skip-btn"
                            data-action="click->discovery-sos-fetch#skipResultRow"
                            data-row-ubi="${this.escapeHtml(rowUbi)}">
                      Skip
                    </button>`
              }
            </div>
          </td>`
        return `<tr class="discovery-results-row${skipped ? " discovery-results-row-skipped" : ""}">${cells}${captureCell}</tr>`
      })
      .join("")

    return `${header}<div class="discovery-results-table-wrap"><table class="discovery-results-table"><thead><tr>${thead}</tr></thead><tbody>${tbody}</tbody></table></div>`
  }

  currentCity() {
    return this.cityFilterTarget?.value || "Vancouver"
  }

  currentBusinessNameSearch() {
    return this.nameFilterTarget?.value || ""
  }

  currentFilters() {
    if (this.businessNameSearchMode) {
      return {
        city: null,
        businessName: this.currentBusinessNameSearch()
      }
    }

    return {
      city: this.currentCity(),
      businessName: this.currentBusinessNameSearch()
    }
  }

  escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  logResult(data) {
    const headerStyle = "color: #fff; font-weight: bold; font-size: 13px;"
    const okStyle = "color: #7dcea0; font-weight: bold;"
    const errStyle = "color: #f1948a; font-weight: bold;"
    const metaStyle = "color: #fff; font-weight: bold;"
    const bodyStyle = "color: #fff; font-family: monospace; font-size: 11px;"

    console.log("%c=== Discovery WA SOS ===", headerStyle)

    if (data.ok) {
      console.log(`%cHTTP ${data.status} · ${data.bytes} bytes · ${data.all_rows?.length ?? 0} rows from SOS`, okStyle)
    } else {
      console.log(`%cHTTP ${data.status} · request failed`, errStyle)
      if (data.error) console.log(`%c${data.error}`, errStyle)
    }

    console.log("%c--- State Call Sent ---", metaStyle)
    // console.log(`%c${JSON.stringify(data.sos_query, null, 2)}`, bodyStyle)

    // console.log("%c--- response preview ---", metaStyle)
    // console.log(`%c${data.preview || "(empty)"}`, bodyStyle)

    // console.log("%c=== end ===", headerStyle)
  }

  logError(error) {
    console.log("%c=== Discovery WA SOS ===", "color: #fff; font-weight: bold; font-size: 13px;")
    console.log(`%cError: ${error.message}`, "color: #f1948a; font-weight: bold;")
    console.log("%c=== end ===", "color: #fff; font-weight: bold; font-size: 13px;")
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
