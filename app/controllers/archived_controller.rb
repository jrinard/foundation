class ArchivedController < ApplicationController
  include NavModuleRequired
  require_nav_module :archived
  # before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    @user = current_user

    if params[:id]
      @chosen_customer = find_customer_by_id(params[:id], sync_superadmin_org: true)
    end

    if params[:l].present?
      @archived_customers = Customer.archived_customers.where(letter: params[:l])
    end

    @contact = Contact.new
    @indiv_contacts = Contact.where("customer_id = ?", params[:id]).order("id ASC").all


  end #index end


  def show
    @customer = Customer.find(params[:id])
    if params[:id]
      @chosen_customer = Customer.find(params[:id])
    end
  end

  def new
    @customer = Customer.new
  end

  def edit
    @customer = Customer.find(params[:id])
  end

  def create
    @customer = Customer.new(customer_params)
    respond_to do |format|
      if @customer.save
        format.html { redirect_to archived_index_path, notice: 'Customer was successfully created.' }
      else
        format.html { render :new }
        format.json { render json: archived_index_path.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @customer = Customer.find(params[:id])
    if @customer.update(customer_params)
        flash[:notice] = "Customer updated!"
        redirect_to archived_index_path(:id => params[:subaction])
    else
      flash[:notice] = "There was an error. Updating the customer."
      render :edit
    end
  end

  def destroy
    @customer = Customer.find(params[:id])
    if @customer.destroy
        # redirect_to archived_index_path
        render json: { redirect: archived_index_path }
        flash[:notice] = "Customer has been deleted!"
    else
      flash[:notice] = "Error customer has NOT been deleted!"
      redirect_to archived_index_path
    end
  end

  private

    def customer_params
      params.require(:customer).permit(:name, :domain, :email, :phone, :webdesign, :hosting, :seo, :ads, :reviewbox, :extra_notes, :active, :archived, :contract_start, :contract_end)
    end
end
