class ListsController < ApplicationController
  include NavModuleRequired
  require_nav_module :leads

  load_and_authorize_resource

  def index

    @lists = List.rank(:row_order) # Don't think this is being used.
  end

  def sort
    @list = List.find(params[:id])
    @list.update(row_order_position: params[:row_order_position])
    head :no_content
  end

  def show
  end

  def new
    @list = List.new
  end

  def edit
  end

  def create
    @list = List.new(list_params)

    respond_to do |format|
      if @list.save
        # format.html { redirect_to customers_path(), notice: 'List was successfully created.' }
        format.json { render json: { redirect: customers_path} }
        flash[:notice] = "List was successfully created"
       # format.json { head :no_content }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @list.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lists/1 or /lists/1.json
  # def update
  #   respond_to do |format|
  #     if @list.update(list_params)
  #       format.html { redirect_to list_url(@list), notice: "List was successfully updated." }
  #       format.json { render :show, status: :ok, location: @list }
  #     else
  #       format.html { render :edit, status: :unprocessable_entity }
  #       format.json { render json: @list.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  def update
    if @list.update(list_params)
      # redirect_to customers_path, notice: "List Updated"
      render json: { redirect: customers_path}
      flash[:notice] = "List Updated"
    else
      # redirect_to customers_path, notice: "List Not Updated"
      render json: { redirect: customers_path}
      flash[:notice] = "List Not Updated"
    end
  end

  def destroy
    @list.destroy
    referrer = request.referrer
    respond_to do |format|
      # format.html { redirect_to customers_path, notice: "List was successfully destroyed." }
      # format.json { head :no_content }
      # format.json { render json: { redirect: customers_path} }
      flash[:notice] = "List was successfully destroyed."

    if referrer.present? && referrer.include?('customers')
      puts "=== Routing to Leads Page"
      render json: { redirect: customers_path }
    end

    end
  end

  private
    def set_list
      @list = List.find(params[:id])
    end

    def list_params
      params.require(:list).permit(:name, :label, :default_for_new_leads)
    end
end
