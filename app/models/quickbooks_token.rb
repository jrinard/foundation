class QuickbooksToken < ApplicationRecord
  include OrganizationScoped

  ENVIRONMENTS = %w[sandbox production].freeze

  belongs_to :organization

  validates :environment, presence: true, inclusion: { in: ENVIRONMENTS }
  validates :organization_id, uniqueness: true

  before_validation :apply_environment_realm_slot, if: :environment_changed?

  def self.integration_for(organization)
    return nil unless organization

    find_or_create_by!(organization: organization) do |record|
      record.environment = "sandbox"
      record.active = false
    end
  end

  def sandbox?
    environment == "sandbox"
  end

  def production?
    environment == "production"
  end

  def connected?
    active? && access_token.present? && effective_realm_id.present?
  end

  def effective_realm_id
    realm_id.presence || (sandbox? ? sandbox_realm_id : production_realm_id)
  end

  def expired?
    expires_at.present? && Time.current >= expires_at
  end

  def disconnect!
    update!(
      active: false,
      access_token: nil,
      refresh_token: nil,
      expires_at: nil
    )
  end

  def apply_realm_from_oauth!(realm_id_value)
    value = realm_id_value.to_s.presence
    return if value.blank?

    attrs = { realm_id: value }
    if sandbox?
      attrs[:sandbox_realm_id] = value
    else
      attrs[:production_realm_id] = value
    end
    update!(attrs)
  end

  private

  def apply_environment_realm_slot
    slot = sandbox? ? sandbox_realm_id : production_realm_id
    self.realm_id = slot if slot.present?
  end
end
