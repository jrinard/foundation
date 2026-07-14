class OrganizationsController < ApplicationController
  before_action :require_superadmin!
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :rename, :update_rename]

  def index
    @sort = params[:sort].presence_in(Organization::INDEX_SORT_OPTIONS) || Organization::INDEX_SORT_DEFAULT

    @organizations = Organization.active.includes(:organization_memberships)

    @organizations = case @sort
                     when "recent"
                       @organizations.order(created_at: :desc)
                     when "quickbooks"
                       @organizations.order(quickbooks_enabled: :desc, name: :asc)
                     else
                       @organizations.order(:name)
                     end
  end

  def show
    @memberships = @organization.organization_memberships.includes(:user).sort_by { |m| m.user.name.to_s.downcase }
  end

  def new
    @organization = Organization.new(sales_pipeline_enabled: true)
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      @organization.provision_defaults!
      redirect_to @organization, notice: "#{@organization.name} is ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def rename
  end

  def update_rename
    if @organization.update(rename_params)
      redirect_to @organization, notice: "Organization renamed."
    else
      render :rename, status: :unprocessable_entity
    end
  end

  def update
    if @organization.update(organization_params)
      redirect_to @organization, notice: "Organization updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if Organization.active.where.not(id: @organization.id).none?
      redirect_to organizations_path, alert: "Cannot deactivate the only active organization."
      return
    end

    name = @organization.name
    @organization.deactivate!
    session.delete(:organization_id) if session[:organization_id].to_i == @organization.id
    redirect_to organizations_path, notice: "#{name} was deactivated and hidden from the list."
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    keys = %i[
      sales_pipeline_enabled
      potentials_enabled
      leads_enabled
      current_clients_enabled
      archived_enabled
      activity_enabled
      quickbooks_enabled
      operations_enabled
      discovery_enabled
    ]
    keys.unshift(:name) if action_name == "create"
    params.require(:organization).permit(*keys)
  end

  def rename_params
    params.require(:organization).permit(:name, :slug)
  end
end
