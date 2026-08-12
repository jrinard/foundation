# frozen_string_literal: true

class DiscoveryBusiness < ApplicationRecord
  include OrganizationScoped

  SOURCE_WA_SOS = "wa_sos"

  STATUS_DISCOVERY = "discovery"
  STATUS_IMPORTED = "imported"
  STATUS_PENDING_ENRICHMENT = "pending_enrichment"
  STATUS_FILTERED_OUT = "filtered_out"
  STATUS_PROMOTED = "promoted"

  STATUSES = [
    STATUS_DISCOVERY,
    STATUS_IMPORTED,
    STATUS_PENDING_ENRICHMENT,
    STATUS_FILTERED_OUT,
    STATUS_PROMOTED
  ].freeze

  STATUS_LABELS = {
    STATUS_DISCOVERY => "Discovery",
    STATUS_IMPORTED => "Discovery",
    STATUS_PENDING_ENRICHMENT => "Pending enrichment",
    STATUS_FILTERED_OUT => "Filtered out",
    STATUS_PROMOTED => "Potential"
  }.freeze

  CHECK_UNCHECKED = "unchecked"
  CHECK_FOUND = "found"
  CHECK_MISSING = "missing"
  CHECK_STATUSES = [CHECK_UNCHECKED, CHECK_FOUND, CHECK_MISSING].freeze

  belongs_to :customer, optional: true

  validates :source, :external_id, :business_name, :status, presence: true
  validates :external_id, uniqueness: { scope: [:organization_id, :source] }
  validates :status, inclusion: { in: STATUSES }
  validates :places_check_status, :facebook_check_status, :linkedin_check_status, :instagram_check_status,
            :website_check_status, :brand_check_status, :hosting_check_status,
            inclusion: { in: CHECK_STATUSES }
  validates :vertical_classification,
            inclusion: { in: Discovery::Verticals::OPTIONS },
            allow_blank: true

  before_validation :sync_check_statuses_from_fields
  before_validation :hydrate_sos_identity_from_raw_payload

  ARCHIVE_FILTER_ALL = "all"
  ARCHIVE_FILTER_DISCOVERIES = "discoveries"
  ARCHIVE_FILTER_POTENTIALS = "potentials"
  ARCHIVE_FILTERS = [
    ARCHIVE_FILTER_ALL,
    ARCHIVE_FILTER_DISCOVERIES,
    ARCHIVE_FILTER_POTENTIALS
  ].freeze

  CAPTURED_SORT_DATE = "date"
  CAPTURED_SORT_NAME = "name"
  CAPTURED_SORT_EMAIL = "email"
  CAPTURED_SORT_PHONE = "phone"
  CAPTURED_SORTS = [
    CAPTURED_SORT_DATE,
    CAPTURED_SORT_NAME,
    CAPTURED_SORT_EMAIL,
    CAPTURED_SORT_PHONE
  ].freeze

  CAPTURED_SORT_LABELS = {
    CAPTURED_SORT_DATE => "Date",
    CAPTURED_SORT_NAME => "Name",
    CAPTURED_SORT_EMAIL => "Has email",
    CAPTURED_SORT_PHONE => "Has phone"
  }.freeze

  scope :recent_first, -> { order(created_at: :desc) }
  scope :not_archived, -> { where(archived: false) }
  scope :archived_only, -> { where(archived: true) }
  scope :working, -> { not_archived }
  scope :discoveries, -> { where.not(status: STATUS_PROMOTED) }
  scope :potentials, -> { where(status: STATUS_PROMOTED) }

  def self.normalize_ubi(ubi)
    ubi.to_s.gsub(/\D/, "")
  end

  def self.for_captured_list(
    view:,
    hide_archived: true,
    archive_filter: ARCHIVE_FILTER_ALL,
    captured_sort: CAPTURED_SORT_DATE
  )
    scope = all

    if view.to_s == "archived"
      scope = scope.archived_only
      case archive_filter.to_s
      when ARCHIVE_FILTER_DISCOVERIES
        scope = scope.discoveries
      when ARCHIVE_FILTER_POTENTIALS
        scope = scope.potentials
      end
    elsif ActiveModel::Type::Boolean.new.cast(hide_archived)
      scope = scope.working
    end

    apply_captured_sort(scope, captured_sort)
  end

  def self.apply_captured_sort(scope, captured_sort)
    case captured_sort.to_s
    when CAPTURED_SORT_NAME
      scope.order(Arel.sql("LOWER(business_name) ASC"), created_at: :desc)
    when CAPTURED_SORT_EMAIL
      scope.order(
        Arel.sql("CASE WHEN COALESCE(NULLIF(TRIM(email), ''), NULL) IS NULL THEN 1 ELSE 0 END"),
        created_at: :desc
      )
    when CAPTURED_SORT_PHONE
      scope.order(
        Arel.sql("CASE WHEN COALESCE(NULLIF(TRIM(phone), ''), NULL) IS NULL THEN 1 ELSE 0 END"),
        created_at: :desc
      )
    else
      scope.recent_first
    end
  end

  def captured_on
    created_at
  end

  def captured_age_label
    days = (Date.current - created_at.to_date).to_i
    case days
    when 0 then "today"
    when 1 then "1 day ago"
    else "#{days} days ago"
    end
  end

  def status_label
    STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def list_status_label
    return status_label if promoted?

    waiting? && !archived? ? "Waiting" : status_label
  end

  def archive!
    update!(archived: true, waiting: false)
  end

  def unarchive!
    update!(archived: false)
  end

  def mark_waiting!
    update!(waiting: true, archived: false)
  end

  def clear_waiting!
    update!(waiting: false)
  end

  def promotable?
    !promoted?
  end

  def promoted?
    status == STATUS_PROMOTED && customer_id.present?
  end

  def scored?
    scored_at.present?
  end

  def score_max_total
    return unless score_breakdown.is_a?(Hash)

    score_breakdown["max_total"].presence
  end

  def score_label
    return unless scored? && !score.nil?

    max = score_max_total
    return if max.blank?

    "#{score}/#{max}"
  end

  def live_score_preview
    Discovery::OpportunityScorePreview.call(discovery_business: self)
  end

  def google_search_url(intent: :contact)
    Discovery::BusinessGoogleSearch.call(discovery_business: self, intent: intent)
  end

  # Canonical field bag for inline detail edits — column values, merged client-side on each save.
  def captured_business_snapshot
    {
      registered_agent_name: registered_agent_name.to_s,
      office_address: office_address.to_s,
      city: city.to_s,
      phone: phone.to_s,
      email: email.to_s,
      website: website.to_s,
      website_check_status: website_check_status.to_s,
      google_rating: google_rating&.to_s,
      google_rating_count: google_rating_count&.to_s,
      google_place_id: google_place_id.to_s,
      places_check_status: places_check_status.to_s,
      vertical_classification: vertical_classification.to_s,
      facebook_url: facebook_url.to_s,
      facebook_check_status: facebook_check_status.to_s,
      linkedin_url: linkedin_url.to_s,
      linkedin_check_status: linkedin_check_status.to_s,
      instagram_url: instagram_url.to_s,
      instagram_check_status: instagram_check_status.to_s
    }
  end

  def display_ubi
    raw_payload_field("UBI#").presence || external_id
  end

  def display_office_address
    office_address.presence || raw_payload_field("Office Address", "Principal Office Address")
  end

  def display_registered_agent_name
    registered_agent_name.presence || raw_payload_field("Reg Name", "Registered Agent Name")
  end

  def display_business_type
    business_type.presence || raw_payload_field("Business Type")
  end

  def display_city
    city.presence ||
      Discovery::Sources::WaSos::FunnelFilters.extract_city(display_office_address.to_s).presence ||
      filter_city.presence
  end

  def source_label
    case source
    when SOURCE_WA_SOS
      "WA Secretary of State"
    else
      source.to_s.humanize
    end
  end

  def google_rating_label
    return "—" if google_rating.blank?

    label = google_rating.to_s
    label += " (#{google_rating_count})" if google_rating_count.present?
    label
  end

  def field_verified?(field_key)
    key = field_key.to_sym

    case key
    when :registered_agent_name
      display_registered_agent_name.present?
    when :office_address
      display_office_address.present?
    when :city
      display_city.present?
    when :phone
      phone.present?
    when :email
      email.present?
    when :website
      website.present? || website_check_status == CHECK_MISSING
    when :google_rating
      google_rating.present?
    when :google_place_id
      google_place_id.present?
    when :vertical_classification
      vertical_classification.present?
    when :facebook_url
      facebook_url.present? || facebook_check_status == CHECK_MISSING
    when :instagram_url
      instagram_url.present? || instagram_check_status == CHECK_MISSING
    when :linkedin_url
      linkedin_url.present? || linkedin_check_status == CHECK_MISSING
    else
      false
    end
  end

  private

  def raw_payload_field(*keys)
    keys.each do |key|
      value = raw_payload[key].to_s.strip
      return value if value.present?
    end
    nil
  end

  def hydrate_sos_identity_from_raw_payload
    return unless source == SOURCE_WA_SOS
    return if raw_payload.blank?

    self.office_address = raw_payload_field("Office Address", "Principal Office Address") if office_address.blank?
    self.registered_agent_name = raw_payload_field("Reg Name", "Registered Agent Name") if registered_agent_name.blank?
    self.business_type = raw_payload_field("Business Type") if business_type.blank?

    return if city.present?

    extracted = Discovery::Sources::WaSos::FunnelFilters.extract_city(office_address.to_s)
    self.city = extracted if extracted.present?
  end

  def sync_check_statuses_from_fields
    self.places_check_status = CHECK_FOUND if google_place_id.present? && places_check_status == CHECK_UNCHECKED
    self.facebook_check_status = CHECK_FOUND if facebook_url.present? && facebook_check_status == CHECK_UNCHECKED
    self.instagram_check_status = CHECK_FOUND if instagram_url.present? && instagram_check_status == CHECK_UNCHECKED
    self.linkedin_check_status = CHECK_FOUND if linkedin_url.present? && linkedin_check_status == CHECK_UNCHECKED
  end
end
