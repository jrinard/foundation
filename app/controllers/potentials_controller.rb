require 'open-uri'
require 'uri'
require 'json'

class PotentialsController < ApplicationController
      include NavModuleRequired
      include OfferingSlotActions
      include OutreachCustomerLoading
      require_nav_module :potentials

      before_action :authenticate_user!
  


 def index
    @user = current_user
    @count_archived = "NA"
      @import = Customer::Import.new

      def download_pdf
        send_file "#{Rails.root}/app/assets/docs/a-customers.csv", type: "application/pdf", x_sendfile: true
      end

      #Filter Sort v2
      if params[:sort_by]
        @potential_customers = Customer.potential_customers.includes(:contacts)
                                .order(params[:sort_by])
      elsif params[:sort_by_manager].present?
        user_id = params[:sort_by_manager].to_i
        @potential_customers = Customer.potential_customers.includes(:contacts)
                               .joins(:user)
                               .where(users: { id: user_id })
                               .order('name asc')
            @chosen_filter_category = "Manager"
            account_manager = User.find_by(id: user_id)
            if account_manager
              @chosen_filter = "#{@chosen_filter_category} #{account_manager.name}"
            end
      else
        @potential_customers = Customer.potential_customers.includes(:contacts)
                               .order('name asc')
      end
    
      if params[:sort_by_offering].present? || params[:sort_by_service].present?
        specific_customers = Customer.potential_customers.includes(:contacts).joins(:offerings)
        specific_customers = specific_customers.order(params[:sort_by]) if params[:sort_by].present?
        @potential_customers = apply_offering_list_filter(specific_customers)
      end

      # @budget_check = false


      if (params[:l])
        @potential_customers = Customer.potential_customers.where("letter = ?", params[:l])
        # @potential_customers = Customer.where("letter = ?", params[:l])
      end


      if params[:search]
        @potential_customers_search = Customer.potential_customers.includes(:contacts)
        #Textacular searching
        # @searchResults = @potential_customers_search.where("name LIKE ?", "%#{params[:search].titleize}%")
  
        #PG_Global Search For Customers
        @searchResults = @potential_customers_search.global_search_customers(params[:search])

        #PG_Global Search For Contacts
        @contacts = Contact.joins(:customer).where(customers: { archived: false })
        @searchResultsContacts = @contacts.global_search_contacts(params[:search])

      end

      if params[:id]
        @chosen_customer = Customer.find(params[:id])
      end


      if params[:active]
        @chosen_customer.update(:active => true)
      end
      if params[:inactive]
        @chosen_customer.update(:active => false)
      end


      ensure_main_offering!
      @main_offering_template = current_organization.offerings.find_by(main: true)
      @customer_offerings_for_search = current_organization.offerings.where(main: true)
      @cs = @main_offering_template

      @customer_offerings_find = Offering.none

      if @chosen_customer
        @customer_offerings_find = Offering.where(customer_id: @chosen_customer.id)
        @cs = @customer_offerings_find.first if @customer_offerings_find.any?

        if outreach_enabled?
          load_outreach_for_customer!(@chosen_customer)
        end

        if params[:add_offerings] == "add_offerings"
          assign_customer_offering_from_template!(@chosen_customer)
          redirect_to potentials_path(id: @chosen_customer.id, l: params[:l], view_notes: "view_notes") and return
        end

        apply_offering_slot_toggles!(@cs) if @cs
      end

      if params[:custom]
        @chosen_customer.update(:custom_project => true)
      end
      if params[:custom_false]
        @chosen_customer.update(:custom_project => false)
      end


      if params[:mtm_true]
        @chosen_customer.update(:monthtomonth => true)
      end
      if params[:mtm_false]
        @chosen_customer.update(:monthtomonth => false)
      end

      if params[:archive]
        @chosen_customer.update(:onBoard => "Archive")
      end
      if params[:onBoard]
        @chosen_customer.update(:onBoard => "Current Not on Board")
      end



      @contact = Contact.new
      @indiv_contacts = Contact.where("customer_id = ?", params[:id]).order("id ASC").all
      @note = Note.new
      ## ActivityNotes
      @indiv_notes = Note.where(:account_note => false, :customer_id => params[:id]).order("id DESC")
      ## AccountNotes
      @indiv_account_notes = Note.where(:account_note => true, :customer_id => params[:id]).order("id DESC")

      assign_account_manager_select_collections

      if params[:id]
        @customer = Customer.find(params[:id])
      end

      @accounts = Customer.order("name asc").pluck(:name, :id)
      @lists = List.rank(:row_order) #Needed for add customer from on home page

      ## may be used for infite scroll.
      respond_to do |format|
        format.html
        format.js { render json: @potential_customers }
      end

  end


end
