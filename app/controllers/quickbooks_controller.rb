class QuickbooksController < ApplicationController
  before_action -> { authorize! :manage, :quickbooks }
  before_action :require_quickbooks_module!

  def auth
    context = QuickbooksServiceContext.new(current_user, organization: current_organization)
    service = QuickbooksService.new(context)
    redirect_to service.get_authorization_url(context), allow_other_host: true
  end

  def callback
    context = QuickbooksServiceContext.new(current_user, organization: current_organization)
    service = QuickbooksService.new(context)
    auth_code = params[:code]
    realm_id = params[:realmId]

    service.fetch_and_store_access_token(auth_code, context, realm_id: realm_id)

    redirect_to settings_path(qb: "qb"), notice: "QuickBooks connected for #{current_organization.name}."
  end

  private

  def require_quickbooks_module!
    return if current_organization&.quickbooks_enabled?

    redirect_to settings_path, alert: "QuickBooks is not enabled for #{current_organization.name}."
  end
end
