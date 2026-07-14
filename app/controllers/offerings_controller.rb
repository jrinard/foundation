class OfferingsController < ApplicationController
  before_action :set_offering, only: [:edit, :update, :destroy]
  before_action -> { authorize! :manage, :settings }, only: [:edit, :update, :destroy, :create]

  def index
    @user = current_user
    @service = Offering.new
  end

  def show
  end

  def new
    @service = Offering.new
  end

  def edit
    if params[:create_main_offering] == "create_main_offering"
      existing = current_organization.offerings.where(main: true)
      existing.update_all(main: false) if existing.exists?
      current_organization.offerings.create!(main: true)
      redirect_to settings_path(offerings: "offerings")
    end
  end

  def create
    @service = Offering.new(offering_params)
    respond_to do |format|
      if @service.save
        format.html { redirect_to root_path, notice: "Offering was successfully created." }
      else
        format.html { render :new }
        format.json { render json: root_path.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @main_offering.update(offering_params)
      @main_offering.sync_template_to_children! if @main_offering.main?
      redirect_to settings_path(offerings: "offerings")
    else
      flash[:alert] = "There was an error updating the offering."
      render :edit
    end
  end

  def destroy
    if @main_offering.destroy
      flash[:notice] = "Offering has been deleted!"
      redirect_to settings_path(offerings: "offerings")
    else
      flash[:notice] = "Error offering has NOT been deleted!"
      redirect_to settings_path(offerings: "offerings")
    end
  end

  private

  def set_offering
    @main_offering = current_organization.offerings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to settings_path(offerings: "offerings"), alert: "Offering not found in #{current_organization.name}." and return
  end

  def offering_params
    params.require(:offering).permit(*Offering.template_slot_param_names, :main, :customer_id)
  end
end
