require 'open-uri'
require 'uri'
require 'json'

class HomeController < ApplicationController
      include NavModuleRequired
      include OfferingSlotActions
      require_nav_module :current_clients
      before_action :authenticate_user!
  

 def index
    @user = current_user
    @count_archived = "NA"
      @import = Customer::Import.new

      def download_pdf
        send_file "#{Rails.root}/app/assets/docs/a-customers.csv", type: "application/pdf", x_sendfile: true
      end

      if params[:sort_by]
        @current_customers = Customer.current_customers.includes(:contacts)
                                .order(params[:sort_by])
      elsif params[:sort_by_manager].present?
        user_id = params[:sort_by_manager].to_i
        @current_customers = Customer.current_customers.includes(:contacts)
                               .joins(:user)
                               .where(users: { id: user_id })
                               .order('name asc')
            @chosen_filter_category = "Manager"
            account_manager = User.find_by(id: user_id)
            if account_manager
              @chosen_filter = "#{@chosen_filter_category} #{account_manager.name}"
            end
      else
        @current_customers = Customer.current_customers.includes(:contacts)
                               .order('name asc')
      end

      if params[:sort_by_offering].present? || params[:sort_by_service].present?
        specific_customers = Customer.current_customers.includes(:contacts).joins(:offerings)
        specific_customers = specific_customers.order(params[:sort_by]) if params[:sort_by].present?
        @current_customers = apply_offering_list_filter(specific_customers)
      end

      # @budget_check = false


      if (params[:l])
        @current_customers = Customer.current_customers.where("letter = ?", params[:l])
        # @current_customers = Customer.where("letter = ?", params[:l])
      end


      if params[:search]
        @current_customers_search = Customer.current_customers.includes(:contacts)
        #Textacular searching
        # @searchResults = @current_customers_search.where("name LIKE ?", "%#{params[:search].titleize}%")
  
        #PG_Global Search For Customers
        @searchResults = @current_customers_search.global_search_customers(params[:search])

        #PG_Global Search For Contacts
        @contacts = Contact.joins(:customer).where(customers: { archived: false })
        @searchResultsContacts = @contacts.global_search_contacts(params[:search])

      end

      if params[:id]
        @chosen_customer = Customer.find(params[:id])
      end


      if params[:active]
        @chosen_customer&.update(:active => true)
      end
      if params[:inactive]
        @chosen_customer&.update(:active => false)
      end


      ensure_main_offering!
      @main_offering_template = current_organization.offerings.find_by(main: true)
      @customer_offerings_for_search = current_organization.offerings.where(main: true)
      @cs = @main_offering_template

      @customer_offerings_find = Offering.none

      if @chosen_customer
        @customer_offerings_find = Offering.where(customer_id: @chosen_customer.id)
        @cs = @customer_offerings_find.first if @customer_offerings_find.any?

        if params[:add_offerings] == "add_offerings"
          assign_customer_offering_from_template!(@chosen_customer)
          redirect_to home_index_path(id: @chosen_customer.id, l: params[:l], view_notes: "view_notes") and return
        end

        apply_offering_slot_toggles!(@cs) if @cs

        if params[:archive].present?
          Customers::Archive.call(customer: @chosen_customer)
          redirect_to home_index_path and return
        end
      end

      if params[:custom]
        @chosen_customer&.update(:custom_project => true)
      end
      if params[:custom_false]
        @chosen_customer&.update(:custom_project => false)
      end


      if params[:mtm_true]
        @chosen_customer&.update(:monthtomonth => true)
      end
      if params[:mtm_false]
        @chosen_customer&.update(:monthtomonth => false)
      end

      if params[:onBoard]
        @chosen_customer&.update(:onBoard => "Current Not on Board")
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

      @customer_invoices = QbInvoice.where("customer_id = ?", params[:id]).order("txn_date desc")

      ## may be used for infite scroll.
      respond_to do |format|
        format.html
        format.js { render json: @current_customers }
      end

  end


  def show_invoices_modal
    @chosen_customer = Customer.find(params[:id]) # Find the customer by the passed ID
    puts

    if Rails.env.development?
      puts "=== Skipping QuickBooks Customer ID check and Auto Call in localhost".yellow
    else
      puts
      puts "=== Chosen Customer Quickbooks ID: #{@chosen_customer.quickbooks_customer_id}".green
    
      if @chosen_customer.quickbooks_customer_id.blank?
        puts "=== QuickBooks Customer ID is missing. Fetching now...".red
        start_fetch_customer()
      end
    
      if @chosen_customer.quickbooks_customer_id.present?
        puts "=== Auto Fetching both Invoices and Sales Receipts".green
        start_fetch_invoices() #* Both Invoices and Sales
      end
    end

  
    @customer_invoices = QbInvoice.where("customer_id = ?", @chosen_customer.id).order("txn_date desc")

    # if params[:sort_by_invoice] === "true"
    #   @customer_invoices = QbInvoice.where(sales_receipt: params[:sort_by_invoice] == "false", customer_id: @chosen_customer.id).order("txn_date desc")           
    # end
    # if params[:sort_by_sr] === "true"
    #   @customer_invoices = QbInvoice.where(sales_receipt: params[:sort_by_sr] == "true", customer_id: @chosen_customer.id).order("txn_date desc")                
    # end

    if params[:sort_by_invoice] == "true"
      @customer_invoices = QbInvoice.where(quickbooks_type: "Invoice", customer_id: @chosen_customer.id).order("txn_date desc")
    end
    
    if params[:sort_by_sr] == "true"
      @customer_invoices = QbInvoice.where(quickbooks_type: "SalesReceipt", customer_id: @chosen_customer.id).order("txn_date desc")
    end
    
    if params[:sort_by_rr] == "true"
      @customer_invoices = QbInvoice.where(quickbooks_type: "RefundReceipt", customer_id: @chosen_customer.id).order("txn_date desc")
    end

    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer })
      end
      format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
    end
  end
  
  #* FETCH INVOICES PDF via Service
  def download_invoice_pdf
    qb_invoice_id = params[:qbInvoiceID]  # Get invoice ID from params
    docNumber = params[:docNumber]  # Get invoice ID from params
  
    return render json: { error: "Missing qbInvoiceID" }, status: :unprocessable_entity unless qb_invoice_id
  
    getting_invoice_pdf(qb_invoice_id, current_user, false, docNumber)
  end

  #* FETCH SALES RECEIPT PDF via Service
  def download_sales_receipt_pdf
    qb_invoice_id = params[:qbInvoiceID]  # Get invoice ID from params
    docNumber = params[:docNumber]  # Get invoice ID from params
  
    return render json: { error: "Missing qbInvoiceID" }, status: :unprocessable_entity unless qb_invoice_id
    #TODO May not need "sales_receipt" anymore
    getting_invoice_pdf(qb_invoice_id, current_user, "sales_receipt", docNumber)
  end

  #* FETCH REFUND RECEIPT PDF via Service
  def download_refund_receipt_pdf
    qb_invoice_id = params[:qbInvoiceID] 
    docNumber = params[:docNumber]  
  
    return render json: { error: "Missing qbInvoiceID" }, status: :unprocessable_entity unless qb_invoice_id
    getting_invoice_pdf(qb_invoice_id, current_user, "refund_receipt", docNumber)
  end
   
  #* FETCH INVOICES via Service V1.1
  def start_fetch_invoices
    puts
    puts "=== HOME CONT - start_fetch_invoices".purple
    @customer = Customer.find(params[:id])
    ### Adding both sales receipts at once
    getting_salesreceipts_for_customer(@customer)
    getting_invoices_for_customer(@customer) ## TODO OFF TEMPORARILY
    getting_refundreceipts_for_customer(@customer)
  end  

  #* FETCH INVOICES SALES RECEIPTS via Servic
  def start_fetch_sales_receipts
    puts
    puts "=== HOME CONT - start_fetch_sales_receipts".purple
    @customer = Customer.find(params[:id])
    getting_salesreceipts_for_customer(@customer)
  end  
  

  #* FETCH CUSTOMER via Service V1.1
  def start_fetch_customer
    puts
    puts "=== HOME CONT - start_fetch_customer Home Cont".red
    @customer = Customer.find(params[:id])
    display_name = @customer.name
    puts display_name.red
    getting_customer_by_display_name(display_name)
  end


  def delete_invoices
    puts "=== Deleting Invoices Locally".red
    customer = Customer.find(params[:id])
    customer.qb_invoices.destroy_all
    redirect_back(fallback_location: root_path)
  end
  

end
