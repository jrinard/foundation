class SettingsController < ApplicationController
  before_action :authorize_settings_read!, only: [:index]
  before_action :authorize_settings_manage!, except: [:index]
  before_action :load_qb_integration, only: [:index, :update_token, :update_quickbooks_integration, :refresh_token, :disconnect_quickbooks]
  before_action :require_valid_transfer_users!, only: [:transfer_customers]

  def index
    @user = current_user
    @main_offering = current_main_offering
    @latest_token = @qb_integration

    assign_account_manager_select_collections
    load_transfer_context
  end

  def transfer_customers
    from_user_id = params[:from_user_id]
    to_user_id = params[:to_user_id]

    transferred = Customer.where(
      user_id: from_user_id,
      organization_id: current_organization.id
    ).update_all(user_id: to_user_id)

    flash[:notice] = "Transferred #{transferred} customer(s) to #{User.find(to_user_id).name}."
    redirect_to settings_path(transfer: "transfer", from_user_id: from_user_id, to_user_id: to_user_id)
  end

  def refresh_token
    authorize! :manage, :quickbooks
    check_and_refresh_quickbooks_token
    flash[:notice] = "Token refresh triggered!"
    redirect_to settings_path(qb: "qb")
  end

  def disconnect_quickbooks
    authorize! :manage, :quickbooks
    @qb_integration.disconnect!
    flash[:notice] = "QuickBooks disconnected for #{current_organization.name}."
    redirect_to settings_path(qb: "qb")
  end

  def update_quickbooks_integration
    authorize! :manage, :quickbooks

    if @qb_integration.update(quickbooks_integration_params)
      flash[:notice] = "QuickBooks settings saved for #{current_organization.name}."
    else
      flash[:alert] = @qb_integration.errors.full_messages.to_sentence
    end
    redirect_to settings_path(qb: "qb")
  end

  def update_modules
    authorize! :manage, :settings

    if current_organization.update(organization_modules_params)
      flash[:notice] = "Features saved for #{current_organization.name}."
    else
      flash[:alert] = current_organization.errors.full_messages.to_sentence
    end
    redirect_to settings_path(features: "features")
  end

  def update_discovery
    authorize! :manage, :settings

    source = DiscoverySource.ensure_wa_sos!(current_organization)
    if source.update(discovery_source_params)
      flash[:notice] = "Discovery source settings saved for #{current_organization.name}."
    else
      flash[:alert] = source.errors.full_messages.to_sentence
    end
    redirect_to settings_path(discovery: "discovery")
  end

  def toggle_customer_offerings_section
    unless current_user.admin? || current_user.superadmin?
      flash[:alert] = "You do not have permission to change that setting."
      redirect_to settings_path(offerings: "offerings") and return
    end

    SiteSetting.toggle_customer_offerings_section!
    visible = SiteSetting.customer_offerings_section_visible?
    flash[:notice] = visible ? "Products/Services section is now visible on customer pages." : "Products/Services section is now hidden on customer pages."
    redirect_to settings_path(offerings: "offerings")
  end

  def toggle_customer_revenue_section
    unless current_user.admin? || current_user.superadmin?
      flash[:alert] = "You do not have permission to change that setting."
      redirect_to settings_path(revenue: "revenue") and return
    end

    SiteSetting.toggle_customer_revenue_section!
    visible = SiteSetting.customer_revenue_section_visible?
    flash[:notice] = visible ? "Revenue section is now visible on customer pages." : "Revenue section is now hidden on customer pages."
    redirect_to settings_path(revenue: "revenue")
  end

  def update_token
    authorize! :manage, :quickbooks

    if @qb_integration.update(quickbooks_token_params.merge(active: true))
      redirect_to settings_path(qb: "qb"), notice: "QuickBooks tokens updated."
    else
      flash[:alert] = @qb_integration.errors.full_messages.to_sentence
      redirect_to settings_path(qb: "qb")
    end
  end

  private

  def load_qb_integration
    @qb_integration = QuickbooksToken.integration_for(current_organization)
  end

  def load_transfer_context
    @from_user = nil
    @to_user = nil
    @allCustomerForManagerA = Customer.none
    @allCustomerForManagerB = Customer.none
    @customer_count = 0

    if params[:from_user_id].present?
      if org_account_manager?(params[:from_user_id])
        @from_user = User.find(params[:from_user_id])
        @allCustomerForManagerA = Customer.where(
          user_id: params[:from_user_id],
          organization_id: current_organization.id
        )
        @customer_count = @allCustomerForManagerA.count
      else
        flash.now[:alert] = "That account manager is not part of #{current_organization.name}."
      end
    end

    if params[:to_user_id].present?
      if org_account_manager?(params[:to_user_id])
        @to_user = User.find(params[:to_user_id])
        @allCustomerForManagerB = Customer.where(
          user_id: params[:to_user_id],
          organization_id: current_organization.id
        )
      else
        flash.now[:alert] = "That account manager is not part of #{current_organization.name}."
      end
    end
  end

  def require_valid_transfer_users!
    return if org_account_manager?(params[:from_user_id]) && org_account_manager?(params[:to_user_id])

    flash[:alert] = "Please select valid account managers for #{current_organization.name}."
    redirect_to settings_path(transfer: "transfer")
  end

  def quickbooks_token_params
    params.require(:quickbooks_token).permit(:access_token, :refresh_token, :expires_at)
  end

  def quickbooks_integration_params
    params.require(:quickbooks_token).permit(
      :environment,
      :realm_id,
      :sandbox_realm_id,
      :production_realm_id,
      :company_name
    )
  end

  def organization_modules_params
    params.require(:organization).permit(
      :potentials_enabled,
      :leads_enabled,
      :discovery_enabled,
      :outreach_enabled,
      :current_clients_enabled,
      :archived_enabled,
      :activity_enabled
    )
  end

  def discovery_source_params
    params.require(:discovery_source).permit(:enabled)
  end

  def authorize_settings_read!
    authorize! :read, :settings
  end

  def authorize_settings_manage!
    authorize! :manage, :settings
  end
end
