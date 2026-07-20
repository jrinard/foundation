const ADDRESS_COLUMN = "Office Address"

// Keep in sync with Discovery::Sources::WaSos::Cities
const SOUTHERN_WA = "Southern WA"
const INDIVIDUAL_CITIES = [
  "Vancouver",
  "Camas",
  "Washougal",
  "Ridgefield",
  "Battle Ground",
  "Hockinson",
  "Brush Prairie",
  "Woodland"
]

export function extractCity(address) {
  if (!address || !/,\s*WA\b/i.test(address)) return null

  const beforeState = address.split(/,\s*WA\b/i)[0]
  const segments = beforeState.split(",").map((segment) => segment.trim()).filter(Boolean)
  return segments[segments.length - 1] || null
}

function matchCities(city) {
  const normalized = (city || "").trim()
  if (!normalized) return []
  return normalized.localeCompare(SOUTHERN_WA, undefined, { sensitivity: "accent" }) === 0
    ? INDIVIDUAL_CITIES
    : [normalized]
}

function filterByCity(rows, city) {
  if (!city) return rows

  const targets = matchCities(city)
  return rows.filter((row) => {
    const extracted = extractCity(row[ADDRESS_COLUMN])
    return (
      extracted &&
      targets.some(
        (target) => extracted.localeCompare(target, undefined, { sensitivity: "accent" }) === 0
      )
    )
  })
}

function filterByBusinessName(rows, query) {
  const normalized = (query || "").trim().toLowerCase()
  if (!normalized) return rows

  return rows.filter((row) => {
    const name = String(row["Business Name"] || "").toLowerCase()
    return name.includes(normalized)
  })
}

// Post-fetch funnel — add more filters here before persisting to DB (Phase 2).
export function applyFunnelFilters(rows, { city, businessName } = {}) {
  let filtered = rows
  filtered = filterByCity(filtered, city)
  filtered = filterByBusinessName(filtered, businessName)
  return filtered
}
