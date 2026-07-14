class ContactsController < ApplicationController
  # before_action :set_contact, only: [:show, :edit, :update, :destroy]

  def index
    @user = current_user
  end #index end



  def show
    @contact = Contact.find(params[:id])
    if params[:id]
      @chosen_customer = Customer.find(params[:id])
    end
  end

  def new
    @contact = Contact.new
  end

  def edit
    @contact = Contact.find(params[:id])
  end

  def create
    @contact = Contact.new(contact_params)
    @c = Customer.where("id = ?", @contact.customer_id).first
    # referrer = request.referrer
    # puts 
    # puts "===== referrer "
    # puts referrer 
    # puts
    if @contact.save

      #TODO Not refreshing yet
        # #Use the referrer to see the location things came from /customers
        # if referrer.present? && referrer.include?('customers')
        #   puts "=== Routing to Leads Page"
        #   render json: { redirect: customers_path }
        #   # format.json { render json: customers_path}
        # elsif referrer.present? && referrer.include?('potentials')
        #   puts "=== Routing to Potential/The List Page"
        #   render json: { redirect: potentials_path }
        #   # format.json { render json: customers_path}
        # else
        #   puts "=== Routing to Home Path with details"
        #   # format.json { render json: root_path}
        #   render json: { redirect: root_path }
        # end


        if @c.archived === false
          if @c.active === true
            redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
            flash[:notice] = "Contact Created!"
          elsif @c.onBoard === "The List"
            redirect_to potentials_path(id: params[:subaction], view_notes: "view_notes")
            flash[:notice] = "Contact Created!"
          else @c.active === false
            redirect_to customers_path(id: params[:subaction])
            flash[:notice] = "Contact Created!"
          end
        else @c.archived === true
            redirect_to archived_index_path(id: params[:subaction])
            flash[:notice] = "Contact Created!"
        end
    else
      flash[:notice] = "There was an error. Please Try Again"
      render :edit
    end
  end

  def update
    @contact = Contact.find(params[:id])
    @c = Customer.where("id = ?", @contact.customer_id).first

    # referrer = request.referrer
    # if @contact.update(contact_params)
      # #TODO Not refreshing yet
      #   #Use the referrer to see the location things came from /customers
      #   if referrer.present? && referrer.include?('customers')
      #     puts "=== Routing to Leads Page"
      #     render json: { redirect: customers_path }
      #     # format.json { render json: customers_path}
      #   elsif referrer.present? && referrer.include?('potentials')
      #     puts "=== Routing to Potential/The List Page"
      #     render json: { redirect: potentials_path }
      #     # format.json { render json: customers_path}
      #   else
      #     puts "=== Routing to Home Path with details"
      #     # format.json { render json: root_path}
      #     render json: { redirect: root_path }
      #   end

      # end
        
  

      respond_to do |format|
        if @contact.update(contact_params)
          if @c.archived === false
            if @c.active === true
              format.html { redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes"), notice: "Contact updated!" }
            elsif @c.onBoard === "The List"
                format.html { redirect_to potentials_path(id: params[:subaction], view_notes: "view_notes"), notice: "Contact updated!" }
            else
              format.html { redirect_to customers_path(id: params[:subaction]), notice: "Contact updated!" }
            end
          else
            format.html { redirect_to archived_index_path(id: params[:subaction]), notice: "Contact updated!" }
          end
        else
          format.html { 
            flash[:notice] = "There was an error updating the contact."
            render :edit
          }
        end
      end
  end
  

  def destroy
    @contact = Contact.find(params[:id])
    @c = Customer.find(@contact.customer_id)
    if @contact.destroy
      flash[:notice] = "Contact has been deleted!"
      redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
    else
      flash[:notice] = "Error contact has NOT been deleted!"
      redirect_to customer_detail_path(@c, l: params[:l], view_notes: "view_notes")
    end
  end

  private

    def contact_import_params
      params.require(:contact_import).permit(:file, :list_id, :user_id)
    end

    def contact_params
      params.require(:contact).permit(:firstname, :lastname, :email, :phone, :phone2, :note, :position, :customer_id)
    end
end
