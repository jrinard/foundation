# frozen_string_literal: true

module CustomerLoading
  extend ActiveSupport::Concern

  private

  def find_customer_by_id(id, sync_superadmin_org: false)
    return nil if id.blank?

    customer = if current_user&.superadmin?
                 Customer.unscoped_by_organization.find_by(id: id)
               else
                 Customer.find_by(id: id)
               end

    apply_organization_context!(customer.organization) if customer && sync_superadmin_org

    customer
  end

  def apply_organization_context!(organization)
    return unless current_user&.superadmin? && organization
    return if organization.id == current_organization&.id

    session[:organization_id] = organization.id
    @current_organization = organization
    Current.organization = organization
    @current_ability = nil
    refresh_customer_scope_ivars!
  end

  def org_transfer_redirect_for(customer, **opts)
    apply_organization_context!(customer.organization)
    url = customer_detail_url(customer, **opts)
    { redirect: url, organization_id: customer.organization_id, organization_name: customer.organization.name }
  end
end
