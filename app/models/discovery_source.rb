# frozen_string_literal: true

class DiscoverySource < ApplicationRecord
  include OrganizationScoped

  WA_SOS = DiscoveryBusiness::SOURCE_WA_SOS

  SOURCE_KEYS = [WA_SOS].freeze

  belongs_to :organization

  has_many :discovery_runs, dependent: :destroy

  validates :source_key, presence: true, inclusion: { in: SOURCE_KEYS }
  validates :source_key, uniqueness: { scope: :organization_id }
  validate :validate_wa_sos_settings, if: -> { source_key == WA_SOS }

  after_save :sync_legacy_organization_columns, if: -> { source_key == WA_SOS }

  def self.ensure_wa_sos!(organization)
    unscoped_by_organization.find_or_create_by!(organization_id: organization.id, source_key: WA_SOS) do |source|
      source.enabled = organization.discovery_wa_sos_enabled
      source.settings = Discovery::Sources::WaSosSettings.from_organization(organization).to_h
    end
  end

  def wa_sos_settings
    Discovery::Sources::WaSosSettings.new(settings)
  end

  def update_wa_sos_settings!(attrs)
    merged = wa_sos_settings.merge(attrs).to_h
    update!(settings: merged)
  end

  private

  def validate_wa_sos_settings
    cadence = settings.to_h["date_cadence"]
    return if cadence.blank?
    return if Discovery::Sources::WaSos::DateCadence.valid?(cadence)

    errors.add(:settings, "date_cadence is invalid")
  end

  def sync_legacy_organization_columns
    config = wa_sos_settings
    organization.update_columns(
      discovery_wa_sos_enabled: enabled,
      discovery_wa_sos_business_type_id: config.business_type_id,
      discovery_wa_sos_active_only: config.active_only,
      discovery_wa_sos_date_cadence: config.date_cadence,
      discovery_wa_sos_city: config.filter_city
    )
  end
end
