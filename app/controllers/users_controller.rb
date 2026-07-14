class UsersController < ApplicationController
  skip_authorization_check only: [:get_user]

  before_action :get_user
  before_action :authorize_users_area!
  before_action :set_org_user, only: [:show, :edit, :update, :destroy]

  def index
    @all_users = User.joins(:organization_memberships)
                     .where(organization_memberships: { organization_id: current_organization.id })
                     .distinct
                     .order(:name)

    all_count = @all_users.count
    super_count = @all_users.where(role: "superadmin").count
    @all_users_minus_admin = all_count - super_count - @all_users.where(role: "user").count

    if params[:uid]
      @u = @all_users.find(params[:uid])
      if params[:user_user]
        @u.update(role: "user")
      end
      if params[:user_man]
        @u.update(role: "manager")
      end
    end

    respond_to do |format|
      format.json { render json: @all_users }
      format.html
    end
  end

  def new
    authorize! :create, User
    @user = User.new
    if current_user.superadmin?
      @organizations = Organization.active.order(:name)
      @user_organization_id = params[:organization_id].presence || current_organization&.id
    end
  end

  def show
    authorize! :read, @user

    if params[:user_user]
      @user.update(role: "user")
    end
    if params[:user_man]
      @user.update(role: "manager")
    end

    respond_to do |format|
      format.json { render json: @user }
      format.html
    end
  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:json, :xml, :html)
  end

  def create
    authorize! :create, User
    @newuser = User.new(user_params)
    respond_to do |format|
      if @newuser.save
        target_org = if current_user.superadmin? && params[:user][:organization_id].present?
                       Organization.find(params[:user][:organization_id])
                     else
                       current_organization
                     end
        OrganizationMembership.create!(user: @newuser, organization: target_org)
        redirect_path = if current_user.superadmin? && params[:user][:organization_id].present?
                          organization_path(params[:user][:organization_id])
                        else
                          users_path
                        end
        format.html { redirect_to redirect_path, notice: "User was successfully created." }
      else
        format.html { redirect_to users_path, notice: "User was NOT created. Please try again." }
      end
    end
  end

  def edit
    authorize! :update, @user
    @organizations = Organization.order(:name) if current_user.superadmin?
    @user_organization_id = @user.primary_membership&.organization_id
  end

  def update
    authorize! :update, @user
    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
    if @user.update(user_params)
      assign_user_organization if current_user.superadmin?
      redirect_to users_path
      flash[:notice] = "Updated User Details"
    else
      @organizations = Organization.active.order(:name) if current_user.superadmin?
      @user_organization_id = @user.primary_membership&.organization_id
      render "edit"
    end
  end

  def destroy
    authorize! :destroy, @user
    if @user.destroy
      flash[:notice] = "User deleted!"
      redirect_to users_path
    else
      render :edit
      flash[:notice] = "Error User not Deleted"
    end
  end

  private

  def get_user
    @user = current_user
    @newuser = User.new
    @current_user = current_user
  end

  def authorize_users_area!
    authorize! :read, User
  end

  def set_org_user
    @user = if current_user.superadmin?
              User.find(params[:id])
            else
              current_organization.users.find(params[:id])
            end
  end

  def assign_user_organization
    org_id = params[:user][:organization_id]
    return if org_id.blank?

    organization = Organization.find(org_id)
    membership = @user.organization_memberships.first_or_initialize
    membership.organization = organization
    membership.save!
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :position)
  end
end
