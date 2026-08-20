# frozen_string_literal: true

module Discovery
  # User-facing "gem" theme labels for discovery data sources (internal keys unchanged).
  #
  # == Gem nicknames ↔ real data sources
  #
  # Search the repo for "River Gems", "Mountain Gems", or +SOURCE_REFERENCE+ when tracing
  # UI copy back to upstream data. Internal DB/API keys stay +wa_sos+ and +data_axel+.
  #
  # | Internal key (+DiscoveryBusiness+ constant) | Gem nickname   | Real source |
  # |---------------------------------------------|----------------|-------------|
  # | +SOURCE_WA_SOS+ (+wa_sos+)                  | River Gems     | Washington Secretary of State (WA SOS) — business filings for recently formed entities; live fetch via +RunWaSosSource+ / +FetchWaSos+ |
  # | +SOURCE_DATA_AXEL+ (+data_axel+)            | Mountain Gems  | Data Axel (Reference Solutions) business list CSVs uploaded per org in +discovery_data_axel_files+ (+DiscoveryDataAxelFile+; merged via +Sources::DataAxel::FileCatalog+) |
  # | +wa_lni+ (enrichment only)                    | Forge Gems     | Washington Labor & Industries (WA L&I) Verify a Contractor — licensed trades lookup via +WaLniVerifyLookup+ |
  #
  # Refine-step labels (+REFINE_*+) are enrichment actions on an already-captured business,
  # not separate collect sources. +REFINE_LEGACY_*+ = Google Places API.
  #
  module GemSources
    SOURCE_REFERENCE = {
      DiscoveryBusiness::SOURCE_WA_SOS => {
        gem_label: "River Gems",
        internal_key: "wa_sos",
        real_source: "Washington Secretary of State (WA SOS) business filing data",
        detail: "Recently formed WA businesses. Collected via live SOS search/fetch (see RunWaSosSource, FetchWaSos, DiscoverySource wa_sos settings)."
      },
      DiscoveryBusiness::SOURCE_DATA_AXEL => {
        gem_label: "Mountain Gems",
        internal_key: "data_axel",
        real_source: "Data Axel / Reference Solutions business list (library CSV export)",
        detail: "Established businesses with richer contact fields. CSV files uploaded in Settings → Discovery → Mountain Gems library (DiscoveryDataAxelFile). Merged on collect/refine via Sources::DataAxel::FileCatalog."
      }
    }.freeze

    ENRICHMENT_WA_LNI = "wa_lni"

    ENRICHMENT_REFERENCE = {
      ENRICHMENT_WA_LNI => {
        gem_label: "Forge Gems",
        internal_key: "wa_lni",
        real_source: "Washington Labor & Industries (WA L&I) Verify a Contractor registry",
        detail: "Licensed contractors and trades — phone, license, and vertical enrichment on Refine (any capture with a business name; UBI on file improves matching). See WaLniVerifyLookup."
      }
    }.freeze
    LABELS = {
      DiscoveryBusiness::SOURCE_WA_SOS => "River Gems",
      DiscoveryBusiness::SOURCE_DATA_AXEL => "Mountain Gems"
    }.freeze

    COLLECT_LABELS = {
      DiscoveryBusiness::SOURCE_WA_SOS => "Collect River Gems",
      DiscoveryBusiness::SOURCE_DATA_AXEL => "Collect Mountain Gems"
    }.freeze

    SUBTEXTS = {
      DiscoveryBusiness::SOURCE_WA_SOS => "Recently formed businesses",
      DiscoveryBusiness::SOURCE_DATA_AXEL => "Established businesses with more contact info"
    }.freeze

    REFINE_LABEL = "Refine"
    REFINE_LEGACY_LABEL = "Refine (Legacy)"
    REFINE_LEGACY_SUBTEXT = "Google Places"
    REFINE_MOUNTAIN_GEMS_LABEL = "Refine from Mountain Gems"
    FORGE_GEMS_LABEL = "Forge Gems"
    REFINE_FORGE_GEMS_LABEL = "Refine from Forge Gems"
    REFINE_FORGE_GEMS_SUBTEXT = "WA L&I licensed contractor lookup"

    module_function

    def source_reference_for(source_key)
      SOURCE_REFERENCE[source_key.to_s] || ENRICHMENT_REFERENCE[source_key.to_s]
    end

    def label_for(source_key)
      LABELS[source_key.to_s] || source_key.to_s.humanize
    end

    def collect_label_for(source_key)
      COLLECT_LABELS[source_key.to_s] || "Collect"
    end

    def subtext_for(source_key)
      SUBTEXTS[source_key.to_s]
    end

    def refine_label
      REFINE_LABEL
    end

    def refine_legacy_label
      REFINE_LEGACY_LABEL
    end

    def refine_legacy_subtext
      REFINE_LEGACY_SUBTEXT
    end

    def refine_mountain_gems_label
      REFINE_MOUNTAIN_GEMS_LABEL
    end

    def forge_gems_label
      FORGE_GEMS_LABEL
    end

    def refine_forge_gems_label
      REFINE_FORGE_GEMS_LABEL
    end

    def refine_forge_gems_subtext
      REFINE_FORGE_GEMS_SUBTEXT
    end
  end
end
