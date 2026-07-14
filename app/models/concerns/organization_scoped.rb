module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :organization

    before_validation :assign_organization_from_current, on: :create

    default_scope -> {
      if Current.organization_id.present?
        where(organization_id: Current.organization_id)
      end
    }

    scope :for_organization, ->(org) { org ? where(organization_id: org.id) : none }
  end

  class_methods do
    def unscoped_by_organization
      unscoped
    end
  end

  private

  def assign_organization_from_current
    self.organization_id ||= Current.organization_id
  end
end
