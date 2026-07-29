class ApplicationController < ActionController::Base
      include CanCan::ControllerAdditions
      include CustomerLoading

      protect_from_forgery unless: -> { request.format.json? }
      # protect_from_forgery with: :exception
      ##

      before_action :configure_permitted_parameters, if: :devise_controller?
      before_action :authenticate_user!
      before_action :set_current_organization, if: :user_signed_in?
      before_action :authorize_crm_access!, if: :user_signed_in?
      before_action :get_customers, if: :user_signed_in?

      helper_method :current_organization,
                    :sales_pipeline_enabled?,
                    :potentials_enabled?,
                    :leads_enabled?,
                    :current_clients_enabled?,
                    :archived_enabled?,
                    :activity_enabled?,
                    :discovery_enabled?,
                    :outreach_enabled?,
                    :quickbooks_enabled_for_org?,
                    :org_admin?,
                    :org_default_path,
                    :customer_detail_path

      # Superadmins who also appear in account-manager pickers and activity filters.
      ACCOUNT_MANAGER_SUPERADMIN_EMAILS = ["josh@lifespringdesign.com"].freeze

      #! Auto QB OFF FOR NOW
      # after_action :check_and_refresh_quickbooks_token, if: :user_signed_in?

      # require 'will_paginate/array'

  # Nav badge counts + shared customer scopes (org-scoped in §12.1).
  def get_customers
    refresh_customer_scope_ivars!
  end

  def refresh_customer_scope_ivars!
    @current_customers = Customer.current_customers.includes(:contacts)
    @potential_customers = Customer.potential_customers.includes(:contacts)
    @archived_customers = Customer.archived_customers.includes(:contacts)

    @count_current = Customer.current_customers
    @count_potential = Customer.potential_customers
    @count_lead = Customer.lead_customers
    @count_archived = Customer.archived_customers
  end

  def current_organization
    @current_organization
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, current_organization)
  end

  def sales_pipeline_enabled?
    current_organization&.sales_pipeline_enabled?
  end

  def potentials_enabled?
    current_organization&.potentials_enabled?
  end

  def leads_enabled?
    current_organization&.leads_enabled?
  end

  def current_clients_enabled?
    current_organization&.current_clients_enabled?
  end

  def archived_enabled?
    current_organization&.archived_enabled?
  end

  def activity_enabled?
    current_organization&.activity_enabled?
  end

  def discovery_enabled?
    current_organization&.discovery_enabled?
  end

  def outreach_enabled?
    current_organization&.outreach_enabled?
  end

  def org_default_path
    org = current_organization
    return root_path unless org

    return discovery_index_path if org.discovery_enabled?
    return outreach_root_path if org.outreach_enabled?
    return customers_path if org.leads_enabled?
    return potentials_path if org.potentials_enabled?
    return home_index_path if org.current_clients_enabled?
    return archived_index_path if org.archived_enabled?
    return activity_index_path if org.activity_enabled?

    settings_path
  end

  def customer_detail_path(customer, **opts)
    return archived_index_path({ id: customer.id }.merge(opts)) if customer.archived?
    return potentials_path({ id: customer.id }.merge(opts)) if customer.onBoard == "The List"
    return customers_path({ id: customer.id }.merge(opts)) unless customer.active?

    home_index_path({ id: customer.id }.merge(opts))
  end

  def customer_detail_url(customer, **opts)
    customer_detail_path(customer, **opts).then { |path| "#{request.base_url}#{path}" }
  end

  def quickbooks_enabled_for_org?
    current_organization&.quickbooks_enabled?
  end

  def org_admin?
    current_user&.admin? || current_user&.superadmin?
  end

  rescue_from CanCan::AccessDenied do
    redirect_to root_path, alert: "You are not authorized to do that."
  end

  def require_superadmin!
    return if current_user&.superadmin?

    redirect_to root_path, alert: "That area is for platform administrators only."
  end

  def authorize_crm_access!
    return if skip_crm_authorization?

    authorize! :read, Customer
  end

  def skip_crm_authorization?
    devise_controller? ||
      controller_name.in?(%w[
        root organization_switches organizations users settings
        quickbooks privacy eula registrations discovery outreach
      ])
  end

  #Stimulus Search
  def search
    query = params[:query]
    @search_results_customers = Customer.includes(:contacts)
                                        .global_search_customers(query)
    @search_results_contacts = Contact.joins(:customer)
                                      .where(customers: { archived: false })
                                      .global_search_contacts(query)

    respond_to do |format|
      format.json do
        render json: {
          customers: @search_results_customers,
          contacts: @search_results_contacts
        }
      end
    end
  end


  def getting_invoice_pdf(qbInvoiceID, context, sales_receipt, docNumber)
    begin
      puts "=== getting_invoice_pdf SERVICE".blue
      @user = current_user
      context = QuickbooksServiceContext.new(@user)
      service = QuickbooksService.new(context)
      puts "=== docNumber".red
      docNumber
      pdf_data, filename, error_message = service.fetch_pdf_invoice(qbInvoiceID, context, sales_receipt, docNumber) 

      puts
      if pdf_data.present? 
        puts 
        puts "=== pdf present"
        puts "Content-Type: #{'application/pdf'}"
        puts "Content-Disposition: inline; filename=\"#{filename}\""
        puts "Expires: 0"
        puts "Cache-Control: must-revalidate, post-check=0, pre-check=0"
        puts "Content-Length: #{pdf_data.bytesize}"

        send_data pdf_data, 
          filename: filename, 
          type: 'application/pdf', 
          disposition: 'inline',
          expires: 0,
          cache_control: 'must-revalidate, post-check=0, pre-check=0',
          content_length: pdf_data.bytesize
        return 
      elsif error_message.present?
        flash[:alert] = error_message
      else
         flash[:alert] = "An unknown error occurred while fetching the PDF." # Handle the case when both are nil
      end
      puts "==== END PDF GET".purple
    rescue StandardError => e
      puts "=== Error getting_invoice_pdf =  #{e.message} #{e}".red
      flash[:alert] = "An error occurred #{e.message}."
    end

    #Getting Customer and Invoices and reloading the same Modal
    @chosen_customer = Customer.find(params[:id]) # Find the customer by the passed ID
    puts
    puts @customer
    puts "=== customer?".blue
    @customer_invoices = QbInvoice.where("customer_id = ?", @customer.id).order("txn_date desc")

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer })
      end
      format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
    end

  end


#* QB Get SalesReceipt via Service
def getting_salesreceipts_for_customer(customer)
  begin
    puts "=== AppControl START getting_salesreceipts_for_customer ".purple
    @user = current_user
    context = QuickbooksServiceContext.new(@user)
    service = QuickbooksService.new(context)
    salesreceipts = service.fetch_salesreceipts_for_customer(customer.quickbooks_customer_id, context)
    puts
    puts "==== AppControl END Sales Receipts".purple
    # puts salesreceipts #TODO not returning salesreceipts
    unless defined?(salesreceipts) && salesreceipts.present?
      puts "=== AppControl - Sales Receipts is undefined, so returning. customer probably does not have any.".red
      flash[:notice] = "Customer does not have any Sales Receipts."
      return
    end

    salesreceipts.each do |sr_data|
      invoice_id = sr_data['Id']
      existing_sales_receipt = QbInvoice.find_by(invoice_id: invoice_id)

      if existing_sales_receipt.nil?
        puts
        puts "=== New Sales Receipt Being Created".green
        puts "=== customer.id =  #{customer.id}".red 
        puts "=== type =  SalesReceipt".red 
        puts "=== invoice_id = #{sr_data['Id']}".red
        puts "=== Balance = #{sr_data['Balance']}".red
        puts "=== domain = #{sr_data['domain']}".red
        puts "=== DocNumber = #{sr_data['DocNumber']}".red
        # puts "=== value = #{sr_data['SalesTermRef']&.dig('value')}".red # TODO Not in Sales Receipts
        # puts "=== name = #{sr_data['SalesTermRef']&.dig('name')}".red # TODO Not in Sales Receipts
        puts "=== TotalAmt = #{sr_data['TxnTaxDetail']&.dig('TotalTax')}".red
        puts "=== total_amount = #{sr_data['TotalAmt']}".red
        # puts "=== due_date = #{sr_data['DueDate']}".red # TODO Not Sales Receipts
        puts "=== txn_date = #{sr_data['TxnDate']}".red #Transaction Date
        puts "=== email_status = #{sr_data['EmailStatus']}".red
        # puts "=== bill_email_address = #{sr_data['BillEmail']&.dig('Address')}".red # TODO Not Sales Receipts
        puts "=== bill_addr_line1 = #{sr_data['BillAddr']&.dig('Line1')}".red
        puts "=== bill_addr_line2 = #{sr_data['BillAddr']&.dig('Line2')}".red
        # puts "=== bill_addr_line3 = #{sr_data['BillAddr']&.dig('Line3')}".red  # TODO Not Sales Receipts
        # puts "=== bill_addr_line4 = #{sr_data['BillAddr']&.dig('Line4')}".red # TODO Not Sales Receipts
        puts "=== customer_ref_value = #{sr_data['CustomerRef']&.dig('value')}".red
        puts "=== customer_ref_name = #{sr_data['CustomerRef']&.dig('name')}".red
        puts "=== invoice_create_time = #{sr_data['MetaData']['CreateTime']}".red
        puts "=== invoice_last_updated_time = #{sr_data['MetaData']['LastUpdatedTime']}".red

        invoice_create_time = Time.zone.parse(sr_data['MetaData']['CreateTime']) if sr_data['MetaData']['CreateTime']
        invoice_last_updated_time = Time.zone.parse(sr_data['MetaData']['LastUpdatedTime']) if sr_data['MetaData']['LastUpdatedTime']


        # Create a new QbInvoice
        qb_invoice_sales_receipt = QbInvoice.new(
          quickbooks_type: "SalesReceipt",
          customer_id: customer.id, 
          invoice_id: sr_data['Id'],
          balance: sr_data['Balance'].to_f,
          domain: sr_data['domain'],
          doc_number: sr_data['DocNumber'],
          # sales_term_ref_value: sr_data['SalesTermRef']&.dig('value'),
          # sales_term_ref_name: sr_data['SalesTermRef']&.dig('name'),
          total_tax: sr_data['TxnTaxDetail']&.dig('TotalTax'),
          total_amount: sr_data['TotalAmt'],
          # due_date: sr_data['DueDate'],
          txn_date: sr_data['TxnDate'],
          email_status: sr_data['EmailStatus'],
          # bill_email_address: sr_data['BillEmail']&.dig('Address'),
          bill_addr_line1: sr_data['BillAddr']&.dig('Line1'),
          bill_addr_line2: sr_data['BillAddr']&.dig('Line2'),
          # bill_addr_line3: sr_data['BillAddr']&.dig('Line3'),
          # bill_addr_line4: sr_data['BillAddr']&.dig('Line4'),
          customer_ref_value: sr_data['CustomerRef']&.dig('value').to_s,
          customer_ref_name: sr_data['CustomerRef']&.dig('name').to_s,
          invoice_create_time: invoice_create_time,
          invoice_last_updated_time: invoice_last_updated_time,
          line_items: sr_data['Line'].map do |line_item|
            {
              id: line_item['Id'],
              line_num: line_item['LineNum'],
              description: line_item['Description'],
              amount: line_item['Amount'].to_f,
              detail_type: line_item['DetailType'],
              unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
              quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
              item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
              item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
            }
          end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
        )
        qb_invoice_sales_receipt.save
        puts "=== Created QbInvoice Sales Receipt with ID: #{qb_invoice_sales_receipt.id}".purple
        puts
        puts
      else
        #* Update existing QbInvoice existing_sales_receipt
        puts "=== Sales Receipt Found now being Updated".green
        # puts existing_sales_receipt
        puts
        puts "=== Balance = #{sr_data['Balance']}".red
        puts "=== domain = #{sr_data['domain']}".red
        puts "=== DocNumber = #{sr_data['DocNumber']}".red 
        # puts "=== value SalesTermRef = #{sr_data['SalesTermRef']&.dig('value')}".red
        # puts "=== name SalesTermRef = #{sr_data['SalesTermRef']&.dig('name')}".red
        puts "=== TotalAmt = #{sr_data['TxnTaxDetail']&.dig('TotalTax')}".red
        puts "=== total_amount = #{sr_data['TotalAmt']}".red
        # puts "=== due_date = #{sr_data['DueDate']}".red
        puts "=== txn_date = #{sr_data['TxnDate']}".red
        puts "=== email_status = #{sr_data['EmailStatus']}".red
        # puts "=== bill_email_address = #{sr_data['BillEmail']&.dig('Address')}".red
        puts "=== bill_addr_line1 = #{sr_data['BillAddr']&.dig('Line1')}".red
        puts "=== bill_addr_line2 = #{sr_data['BillAddr']&.dig('Line2')}".red
        # puts "=== bill_addr_line3 = #{sr_data['BillAddr']&.dig('Line3')}".red
        # puts "=== bill_addr_line4 = #{sr_data['BillAddr']&.dig('Line4')}".red
        puts "=== customer_ref_value = #{sr_data['CustomerRef']&.dig('value')}".red
        puts "=== customer_ref_name = #{sr_data['CustomerRef']&.dig('name')}".red
        puts "=== invoice_create_time = #{sr_data['MetaData']['CreateTime']}".red
        puts "=== invoice_last_updated_time = #{sr_data['MetaData']['LastUpdatedTime']}".red


        #* Only Update Invoice(Sales Receipt) if the invoice_last_updated_time is newer then the previous time?
        puts
        puts "=== Checking if the (Sales Receipt) has been updated based on the last updated time".purple
        @existing_data_invoice_last_updated_time = existing_sales_receipt.is_a?(Hash) ? existing_sales_receipt["invoice_last_updated_time"] : existing_sales_receipt.invoice_last_updated_time
        puts "=== existing invoice  (Sales Receipt)data - last_updated_time #{@existing_data_invoice_last_updated_time}".purple

        # Get the new invoice's last update time
        @new_data_invoice_last_updated_time = Time.parse(sr_data.dig("MetaData", "LastUpdatedTime")) rescue nil
        puts "======== new invoice (Sales Receipt) data - last_updated_time #{@new_data_invoice_last_updated_time}".purple

        # Compare timestamps before updating
        if @new_data_invoice_last_updated_time && 
          (@existing_data_invoice_last_updated_time.nil? || @new_data_invoice_last_updated_time > @existing_data_invoice_last_updated_time)
            puts
            puts "=== New Invoice (Sales Receipt) Data is actually different so update the invoice".green
            puts

            invoice_create_time = Time.zone.parse(sr_data['MetaData']['CreateTime']) if sr_data['MetaData']['CreateTime']
            invoice_last_updated_time = Time.zone.parse(sr_data['MetaData']['LastUpdatedTime']) if sr_data['MetaData']['LastUpdatedTime']
            #Not updating customer.id or invoice[id] because those should be locked in.
            existing_sales_receipt.assign_attributes(
              quickbooks_type: "SalesReceipt",
              balance: sr_data['Balance'],
              domain: sr_data['domain'],
              doc_number: sr_data['DocNumber'],
              total_tax: sr_data['TxnTaxDetail']&.dig('TotalTax'),
              total_amount: sr_data['TotalAmt'],
              txn_date: sr_data['TxnDate'],
              email_status: sr_data['EmailStatus'],
              bill_email_address: sr_data['BillEmail']&.dig('Address'),
              bill_addr_line1: sr_data['BillAddr']&.dig('Line1'),
              bill_addr_line2: sr_data['BillAddr']&.dig('Line2'),
              customer_ref_value: sr_data['CustomerRef']&.dig('value').to_s,
              customer_ref_name: sr_data['CustomerRef']&.dig('name').to_s,
              invoice_create_time: invoice_create_time,
              invoice_last_updated_time: invoice_last_updated_time,
              line_items: sr_data['Line'].map do |line_item|
                {
                  id: line_item['Id'],
                  line_num: line_item['LineNum'],
                  description: line_item['Description'],
                  amount: line_item['Amount'].to_f,
                  detail_type: line_item['DetailType'],
                  unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
                  quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
                  item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
                  item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
                }
              end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
            )
            existing_sales_receipt.save!
            puts 
            puts "=== Updated QbInvoice (Sales Receipt) with ID: #{existing_sales_receipt.id}".purple
            puts "======".purple
            puts
        else 
            puts
            puts "====== New (Sales Receipt) Data has not changed from the current so no updates were made".green
            puts
        end
      end
    end 
          

    rescue StandardError => e
      puts "=== Error getting_salesreceipts_for_customer =  #{e.message} #{e}".red
      flash[:alert] = "An error occurred #{e.message}."
    end
 
    #Getting Customer and Invoices and reloading the same Modal
    @chosen_customer = Customer.find(params[:id]) # Find the customer by the passed ID
    puts
    puts @customer
    @customer_invoices = QbInvoice.where("customer_id = ?", @customer.id).order("txn_date desc")

    return
    #TURNING OFF to Avoid Double Render Error for all the auto syncing
    # respond_to do |format|
    #   format.turbo_stream do
    #     render turbo_stream: turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer })
    #   end
    #   format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
    # end

  end



#* QB Get invoices via Service V1.2
def getting_invoices_for_customer(customer)
  begin
    puts "=== AppControl START getting_invoices_for_customer ".purple
    @user = current_user
    context = QuickbooksServiceContext.new(@user)
    service = QuickbooksService.new(context)
    invoices = service.fetch_invoices_for_customer(customer.quickbooks_customer_id, context)
    puts "==== AppControl END Invoices".purple
    # puts invoices #TODO Return invoices

    unless defined?(invoices) && invoices.present?
      puts "=== Invoices is undefined, so returning. customer probably does not have any.".red
      flash[:notice] = "Customer does not have any Invoices."
      return
    end

    invoices.each do |invoice_data|
      invoice_id = invoice_data['Id']
      existing_invoice = QbInvoice.find_by(invoice_id: invoice_id)

      if existing_invoice.nil?
        puts
        puts "=== New Invoice Being Created".green
        puts "=== customer.id =  #{customer.id}".red
        puts "=== invoice_id = #{invoice_data['Id']}".red
        puts "=== Balance = #{invoice_data['Balance']}".red
        puts "=== domain = #{invoice_data['domain']}".red
        puts "=== DocNumber = #{invoice_data['DocNumber']}".red
        # puts "=== value = #{invoice_data['SalesTermRef']&.dig('value')}".red
        # puts "=== name = #{invoice_data['SalesTermRef']&.dig('name')}".red
        puts "=== TotalAmt = #{invoice_data['TxnTaxDetail']&.dig('TotalTax')}".red
        puts "=== total_amount = #{invoice_data['TotalAmt']}".red
        puts "=== due_date = #{invoice_data['DueDate']}".red
        puts "=== txn_date = #{invoice_data['TxnDate']}".red
        puts "=== email_status = #{invoice_data['EmailStatus']}".red
        puts "=== bill_email_address = #{invoice_data['BillEmail']&.dig('Address')}".red
        puts "=== bill_addr_line1 = #{invoice_data['BillAddr']&.dig('Line1')}".red
        puts "=== bill_addr_line2 = #{invoice_data['BillAddr']&.dig('Line2')}".red
        puts "=== bill_addr_line3 = #{invoice_data['BillAddr']&.dig('Line3')}".red
        puts "=== bill_addr_line4 = #{invoice_data['BillAddr']&.dig('Line4')}".red
        puts "=== customer_ref_value = #{invoice_data['CustomerRef']&.dig('value')}".red
        puts "=== customer_ref_name = #{invoice_data['CustomerRef']&.dig('name')}".red
        puts "=== invoice_create_time = #{invoice_data['MetaData']['CreateTime']}".red
        puts "=== invoice_last_updated_time = #{invoice_data['MetaData']['LastUpdatedTime']}".red

        invoice_create_time = Time.zone.parse(invoice_data['MetaData']['CreateTime']) if invoice_data['MetaData']['CreateTime']
        invoice_last_updated_time = Time.zone.parse(invoice_data['MetaData']['LastUpdatedTime']) if invoice_data['MetaData']['LastUpdatedTime']


        # Create a new QbInvoice
        qb_invoice = QbInvoice.new(
          customer_id: customer.id, 
          quickbooks_type: "Invoice",
          invoice_id: invoice_data['Id'],
          balance: invoice_data['Balance'].to_f,
          domain: invoice_data['domain'],
          doc_number: invoice_data['DocNumber'],
          # sales_term_ref_value: invoice_data['SalesTermRef']&.dig('value'),
          # sales_term_ref_name: invoice_data['SalesTermRef']&.dig('name'),
          total_tax: invoice_data['TxnTaxDetail']&.dig('TotalTax'),
          total_amount: invoice_data['TotalAmt'],
          due_date: invoice_data['DueDate'],
          txn_date: invoice_data['TxnDate'],
          email_status: invoice_data['EmailStatus'],
          bill_email_address: invoice_data['BillEmail']&.dig('Address'),
          bill_addr_line1: invoice_data['BillAddr']&.dig('Line1'),
          bill_addr_line2: invoice_data['BillAddr']&.dig('Line2'),
          bill_addr_line3: invoice_data['BillAddr']&.dig('Line3'),
          bill_addr_line4: invoice_data['BillAddr']&.dig('Line4'),
          customer_ref_value: invoice_data['CustomerRef']&.dig('value').to_s,
          customer_ref_name: invoice_data['CustomerRef']&.dig('name').to_s,
          invoice_create_time: invoice_create_time,
          invoice_last_updated_time: invoice_last_updated_time,
          line_items: invoice_data['Line'].map do |line_item|
            {
              id: line_item['Id'],
              line_num: line_item['LineNum'],
              description: line_item['Description'],
              amount: line_item['Amount'].to_f,
              detail_type: line_item['DetailType'],
              unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
              quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
              item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
              item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
            }
          end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
        )
        qb_invoice.save
        puts "=== Created QbInvoice with ID: #{qb_invoice.id}".green
        puts
        puts
      else
        #* Update existing QbInvoice
        puts
        puts "=== Invoice Found now being Updated".green
        # puts existing_invoice
        puts
        puts "=== Balance = #{invoice_data['Balance']}".red
        puts "=== domain = #{invoice_data['domain']}".red
        puts "=== DocNumber = #{invoice_data['DocNumber']}".red
        # puts "=== value SalesTermRef = #{invoice_data['SalesTermRef']&.dig('value')}".red
        # puts "=== name SalesTermRef = #{invoice_data['SalesTermRef']&.dig('name')}".red
        puts "=== TotalAmt = #{invoice_data['TxnTaxDetail']&.dig('TotalTax')}".red
        puts "=== total_amount = #{invoice_data['TotalAmt']}".red
        puts "=== due_date = #{invoice_data['DueDate']}".red
        puts "=== txn_date = #{invoice_data['TxnDate']}".red
        puts "=== email_status = #{invoice_data['EmailStatus']}".red
        puts "=== bill_email_address = #{invoice_data['BillEmail']&.dig('Address')}".red
        puts "=== bill_addr_line1 = #{invoice_data['BillAddr']&.dig('Line1')}".red
        puts "=== bill_addr_line2 = #{invoice_data['BillAddr']&.dig('Line2')}".red
        puts "=== bill_addr_line3 = #{invoice_data['BillAddr']&.dig('Line3')}".red
        puts "=== bill_addr_line4 = #{invoice_data['BillAddr']&.dig('Line4')}".red
        puts "=== customer_ref_value = #{invoice_data['CustomerRef']&.dig('value')}".red
        puts "=== customer_ref_name = #{invoice_data['CustomerRef']&.dig('name')}".red
        puts "=== invoice_create_time = #{invoice_data['MetaData']['CreateTime']}".red
        puts "=== invoice_last_updated_time = #{invoice_data['MetaData']['LastUpdatedTime']}".red


        #* Only Update Invoice if the invoice_last_updated_time is newer then the previous time?
        puts
        puts "=== Checking if the Invoice has been updated based on the last updated time".purple
        @existing_data_invoice_last_updated_time = existing_invoice.is_a?(Hash) ? existing_invoice["invoice_last_updated_time"] : existing_invoice.invoice_last_updated_time
        puts "=== existing invoice data - last_updated_time #{@existing_data_invoice_last_updated_time}".purple

        # Get the new invoice's last update time
        @new_data_invoice_last_updated_time = Time.parse(invoice_data.dig("MetaData", "LastUpdatedTime")) rescue nil
        puts "======== new invoice data - last_updated_time #{@new_data_invoice_last_updated_time}".purple

        # Compare timestamps before updating
        if @new_data_invoice_last_updated_time && 
          (@existing_data_invoice_last_updated_time.nil? || @new_data_invoice_last_updated_time > @existing_data_invoice_last_updated_time)
            puts
            puts "=== New Invoice Data is actually different so update the invoice".green
            puts

            invoice_create_time = Time.zone.parse(invoice_data['MetaData']['CreateTime']) if invoice_data['MetaData']['CreateTime']
            invoice_last_updated_time = Time.zone.parse(invoice_data['MetaData']['LastUpdatedTime']) if invoice_data['MetaData']['LastUpdatedTime']
            #Not updating customer.id or invoice[id] because those should be locked in.
            existing_invoice.assign_attributes(
              quickbooks_type: "Invoice",
              balance: invoice_data['Balance'],
              domain: invoice_data['domain'],
              doc_number: invoice_data['DocNumber'],
              # sales_term_ref_value: invoice_data['SalesTermRef']&.dig('value'),
              # sales_term_ref_name: invoice_data['SalesTermRef']&.dig('name'),
              total_tax: invoice_data['TxnTaxDetail']&.dig('TotalTax'),
              total_amount: invoice_data['TotalAmt'],
              due_date: invoice_data['DueDate'],
              txn_date: invoice_data['TxnDate'],
              email_status: invoice_data['EmailStatus'],
              bill_email_address: invoice_data['BillEmail']&.dig('Address'),
              bill_addr_line1: invoice_data['BillAddr']&.dig('Line1'),
              bill_addr_line2: invoice_data['BillAddr']&.dig('Line2'),
              bill_addr_line3: invoice_data['BillAddr']&.dig('Line3'),
              bill_addr_line4: invoice_data['BillAddr']&.dig('Line4'),
              customer_ref_value: invoice_data['CustomerRef']&.dig('value').to_s,
              customer_ref_name: invoice_data['CustomerRef']&.dig('name').to_s,
              invoice_create_time: invoice_create_time,
              invoice_last_updated_time: invoice_last_updated_time,
              line_items: invoice_data['Line'].map do |line_item|
                {
                  id: line_item['Id'],
                  line_num: line_item['LineNum'],
                  description: line_item['Description'],
                  amount: line_item['Amount'].to_f,
                  detail_type: line_item['DetailType'],
                  unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
                  quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
                  item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
                  item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
                }
              end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
            )
            existing_invoice.save!
            puts 
            puts "=== Updated QbInvoice with ID: #{existing_invoice.id}".purple
            puts "======".purple
            puts
        else 
            puts
            puts "====== New Invoice Data has NOT changed from the current so no updates were made".green
            puts
        end
      end
    end 
          

    rescue StandardError => e
      puts "=== Error getting_invoices_for_customer =  #{e.message} #{e}".red
      flash[:alert] = "An error occurred #{e.message}."
    end

    #TURNING OFF to Avoid Double Render Error for all the auto syncing - This does work if the button is manual

    #Getting Customer and Invoices and reloading the same Modal
    # @chosen_customer = Customer.find(params[:id]) # Find the customer by the passed ID
    # puts
    # puts @customer
    # @customer_invoices = QbInvoice.where("customer_id = ?", @customer.id).order("txn_date desc")


    # respond_to do |format|
    #   format.turbo_stream do
    #     render turbo_stream: turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer })
    #   end
    #   format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
    # end

  end

  def getting_refundreceipts_for_customer(customer)
    begin
      puts "=== AppControl START getting_refundreceipts_for_customer ".purple
      @user = current_user
      context = QuickbooksServiceContext.new(@user)
      service = QuickbooksService.new(context)
      refundreceipts = service.fetch_refundreceipts_for_customer(customer.quickbooks_customer_id, context)
      puts
      puts "==== AppControl END Refund Receipts".purple
      # puts refundreceipts 
      unless defined?(refundreceipts) && refundreceipts.present?
        puts "=== AppControl - Refund Receipts is undefined, so returning. customer probably does not have any.".red
        flash[:notice] = "Customer does not have any Refund Receipts."
        return
      end
  
      refundreceipts.each do |ref_data|
        invoice_id = ref_data['Id']
        existing_refund_receipt = QbInvoice.find_by(invoice_id: invoice_id)
  
        if existing_refund_receipt.nil?
          puts
          puts "=== New Refund Receipt Being Created".green
          puts "=== customer.id =  #{customer.id}".red 
          puts "=== invoice_id = #{ref_data['Id']}".red
          puts "=== Balance = #{ref_data['Balance']}".red
          puts "=== domain = #{ref_data['domain']}".red
          puts "=== DocNumber = #{ref_data['DocNumber']}".red
          puts "=== TotalAmt = #{ref_data['TxnTaxDetail']&.dig('TotalTax')}".red
          puts "=== total_amount = #{ref_data['TotalAmt']}".red
          puts "=== txn_date = #{ref_data['TxnDate']}".red #Transaction Date
          # puts "=== email_status = #{ref_data['EmailStatus']}".red #Not in Refund
          puts "=== bill_email_address = #{ref_data['BillEmail']&.dig('Address')}".red #Unique to Refund
          puts "=== bill_addr_line1 = #{ref_data['BillAddr']&.dig('Line1')}".red
          puts "=== bill_addr_line2 = #{ref_data['BillAddr']&.dig('Line2')}".red
          puts "=== customer_ref_value = #{ref_data['CustomerRef']&.dig('value')}".red
          puts "=== customer_ref_name = #{ref_data['CustomerRef']&.dig('name')}".red
          puts "=== invoice_create_time = #{ref_data['MetaData']['CreateTime']}".red
          puts "=== invoice_last_updated_time = #{ref_data['MetaData']['LastUpdatedTime']}".red
  
          invoice_create_time = Time.zone.parse(ref_data['MetaData']['CreateTime']) if ref_data['MetaData']['CreateTime']
          invoice_last_updated_time = Time.zone.parse(ref_data['MetaData']['LastUpdatedTime']) if ref_data['MetaData']['LastUpdatedTime']
  
  
          # Create a new QbInvoice
          qb_invoice_refund_receipt = QbInvoice.new(
            quickbooks_type: "RefundReceipt",
            customer_id: customer.id, 
            invoice_id: ref_data['Id'],
            balance: ref_data['Balance'].to_f,
            domain: ref_data['domain'],
            doc_number: ref_data['DocNumber'],
            total_tax: ref_data['TxnTaxDetail']&.dig('TotalTax'),
            total_amount: ref_data['TotalAmt'],
            txn_date: ref_data['TxnDate'],
            # email_status: ref_data['EmailStatus'],
            bill_email_address: ref_data['BillEmail']&.dig('Address'),
            bill_addr_line1: ref_data['BillAddr']&.dig('Line1'),
            bill_addr_line2: ref_data['BillAddr']&.dig('Line2'),
            customer_ref_value: ref_data['CustomerRef']&.dig('value').to_s,
            customer_ref_name: ref_data['CustomerRef']&.dig('name').to_s,
            invoice_create_time: invoice_create_time,
            invoice_last_updated_time: invoice_last_updated_time,
            line_items: ref_data['Line'].map do |line_item|
              {
                id: line_item['Id'],
                line_num: line_item['LineNum'],
                description: line_item['Description'],
                amount: line_item['Amount'].to_f,
                detail_type: line_item['DetailType'],
                unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
                quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
                item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
                item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
              }
            end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
          )
          qb_invoice_refund_receipt.save
          puts "=== Created QbInvoice Refund Receipt with ID: #{qb_invoice_refund_receipt.id}".purple
          puts
          puts
        else
          #* Update existing QbInvoice existing_refund_receipt
          puts "=== Refund Receipt found now being Updated".green
          # puts existing_refund_receipt
          puts "=== customer.id =  #{customer.id}".yellow 
          puts "=== invoice_id = #{ref_data['Id']}".yellow
          puts "=== Balance = #{ref_data['Balance']}".yellow
          puts "=== domain = #{ref_data['domain']}".yellow
          puts "=== DocNumber = #{ref_data['DocNumber']}".yellow
          puts "=== TotalAmt = #{ref_data['TxnTaxDetail']&.dig('TotalTax')}".yellow
          puts "=== total_amount = #{ref_data['TotalAmt']}".yellow
          puts "=== txn_date = #{ref_data['TxnDate']}".yellow #Transaction Date
          puts "=== bill_email_address = #{ref_data['BillEmail']&.dig('Address')}".yellow #Unique to Refund
          puts "=== bill_addr_line1 = #{ref_data['BillAddr']&.dig('Line1')}".yellow
          puts "=== bill_addr_line2 = #{ref_data['BillAddr']&.dig('Line2')}".yellow
          puts "=== customer_ref_value = #{ref_data['CustomerRef']&.dig('value')}".yellow
          puts "=== customer_ref_name = #{ref_data['CustomerRef']&.dig('name')}".yellow
          puts "=== invoice_create_time = #{ref_data['MetaData']['CreateTime']}".yellow
          puts "=== invoice_last_updated_time = #{ref_data['MetaData']['LastUpdatedTime']}".yellow
  
  
          #* Only Update Invoice(Refund Receipt) if the invoice_last_updated_time is newer then the previous time?
          puts
          puts "=== Checking if the (Refund Receipt) has been updated based on the last updated time".purple
          @existing_data_refund_last_updated_time = existing_refund_receipt.is_a?(Hash) ? existing_refund_receipt["invoice_last_updated_time"] : existing_refund_receipt.invoice_last_updated_time
          puts "=== existing invoice  (Refund Receipt)data - last_updated_time #{@existing_data_refund_last_updated_time}".purple
  
          # Get the new receipts last update time
          @new_data_refund_last_updated_time = Time.parse(ref_data.dig("MetaData", "LastUpdatedTime")) rescue nil
          puts "======== new invoice (Sales Receipt) data - last_updated_time #{@new_data_refund_last_updated_time}".purple
  
          # Compare timestamps before updating
          if @new_data_refund_last_updated_time && 
            (@existing_data_refund_last_updated_time.nil? || @new_data_refund_last_updated_time > @existing_data_refund_last_updated_time)
              puts
              puts "=== New Invoice (Refund Receipt) Data is actually different so update the invoice".green
              puts
  
              invoice_create_time = Time.zone.parse(ref_data['MetaData']['CreateTime']) if ref_data['MetaData']['CreateTime']
              invoice_last_updated_time = Time.zone.parse(ref_data['MetaData']['LastUpdatedTime']) if ref_data['MetaData']['LastUpdatedTime']
              #Not updating customer.id or invoice[id] because those should be locked in.
              existing_refund_receipt.assign_attributes(
                quickbooks_type: "RefundReceipt",
                customer_id: customer.id, 
                invoice_id: ref_data['Id'],
                balance: ref_data['Balance'].to_f,
                domain: ref_data['domain'],
                doc_number: ref_data['DocNumber'],
                total_tax: ref_data['TxnTaxDetail']&.dig('TotalTax'),
                total_amount: ref_data['TotalAmt'],
                txn_date: ref_data['TxnDate'],
                # email_status: ref_data['EmailStatus'],
                bill_email_address: ref_data['BillEmail']&.dig('Address'),
                bill_addr_line1: ref_data['BillAddr']&.dig('Line1'),
                bill_addr_line2: ref_data['BillAddr']&.dig('Line2'),
                customer_ref_value: ref_data['CustomerRef']&.dig('value').to_s,
                customer_ref_name: ref_data['CustomerRef']&.dig('name').to_s,
                invoice_create_time: invoice_create_time,
                invoice_last_updated_time: invoice_last_updated_time,
                line_items: ref_data['Line'].map do |line_item|
                  {
                    id: line_item['Id'],
                    line_num: line_item['LineNum'],
                    description: line_item['Description'],
                    amount: line_item['Amount'].to_f,
                    detail_type: line_item['DetailType'],
                    unit_price: line_item['SalesItemLineDetail']&.dig('UnitPrice').to_f, 
                    quantity: line_item['SalesItemLineDetail']&.dig('Qty'), 
                    item_ref_value: line_item['SalesItemLineDetail']&.dig('ItemRef', 'value').to_s,
                    item_ref_name: line_item['SalesItemLineDetail']&.dig('ItemRef', 'name') 
                  }
                end.to_json #TODO this might be the wrong format read with JSON.parse(your_model.line_items)
              )
              existing_refund_receipt.save!
              puts 
              puts "=== Updated QbInvoice (Refund Receipt) with ID: #{existing_refund_receipt.id}".purple
              puts "======".purple
              puts
          else 
              puts
              puts "====== New (Refund Receipt) Data has not changed from the current so no updates were made".green
              puts
          end
        end
      end 
            
  
      rescue StandardError => e
        puts "=== Error getting_refundreceipts_for_customer =  #{e.message} #{e}".red
        flash[:alert] = "An error occurred #{e.message}."
      end
   
      #Getting Customer and Invoices and reloading the same Modal
      @chosen_customer = Customer.find(params[:id]) # Find the customer by the passed ID
      puts
      puts @customer
      @customer_invoices = QbInvoice.where("customer_id = ?", @customer.id).order("txn_date desc")
  
      return
      #TURNING OFF to Avoid Double Render Error for all the auto syncing
      # respond_to do |format|
      #   format.turbo_stream do
      #     render turbo_stream: turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer })
      #   end
      #   format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
      # end
    end
  
  


    #* QB Get Customer via Service V1.2
    def getting_customer_by_display_name(display_name)
      begin
        puts "=== getting_customer_by_display_name".red
        @user = current_user
        context = QuickbooksServiceContext.new(@user)
        service = QuickbooksService.new(context)
        customerData = service.fetch_customer_by_display_name(display_name, context)
        puts
        # puts "==== Customer returned to application controller2".red
        # puts customerData
        puts 
        if customerData.is_a?(String) && (customerData.include?("AuthenticationFailed") || customerData.include?("401"))
          flash[:notice] = "QB Auth Error: You need to refresh your key. #{customerData}"
        end
        
        puts
        @chosen_customer = Customer.find_by(id: params[:id])
        @chosen_customer.reload 
        if customerData && !(customerData.include?("AuthenticationFailed"))
          puts "Customer Data:".red
          puts "===  ID: #{customerData['Id']}".red
          puts "===  Display Name: #{customerData['DisplayName']}".red
          puts "===  Company Name: #{customerData['CompanyName']}".red
          puts "===  Balance: #{customerData['Balance']}".red
          puts "===  Given Name: #{customerData['GivenName']}".red
          puts "===  Family Name: #{customerData['FamilyName']}".red

          #* Syncing ID - Note you can sync other data here as well
          # @chosen_customer = Customer.find(params[:id])
          @chosen_customer.update(quickbooks_customer_id: customerData['Id']) 
          puts "===!!! FINAL RESULT QB Customer ID saved: #{@chosen_customer.quickbooks_customer_id} !!!===".green
          puts
        else
          puts "=== No customer data found for display name: #{display_name}"
        end

      rescue StandardError => e
        puts "=== Error getting_customer_by_display_name =  #{e.message}".red
        flash[:alert] = "An error occurred #{e.message}."
      end
        @chosen_customer.reload
        # puts 
        # puts @chosen_customer.inspect

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
        
        @updated_customer = Customer.find_by(id: params[:id])
    
      #TURNING OFF to Avoid Double Render Error for all the auto syncing
        # respond_to do |format|
        #   format.turbo_stream do
        #     render turbo_stream: [
        #       turbo_stream.replace("modal", partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer }),
        #       turbo_stream.replace("customer_info", partial: "home/customer_info", locals: { customer: @chosen_customer })
        #     ]
        #   end
        #   format.html { render partial: "home/invoices_modal", locals: { invoices: @customer_invoices, customer: @chosen_customer } }
        # end
      end




  
      private

  def account_managers_for_select
    return [] unless current_organization

    org_user_ids = OrganizationMembership.where(organization_id: current_organization.id).select(:user_id)
    managers = User.where(id: org_user_ids, role: "manager").order(created_at: :desc)
    supers = User.where(email: ACCOUNT_MANAGER_SUPERADMIN_EMAILS)
    (managers.to_a + supers.to_a).uniq(&:id)
  end

  def org_account_manager?(user_id)
    return false if user_id.blank?

    account_managers_for_select.any? { |user| user.id == user_id.to_i }
  end

  def current_main_offering
    current_organization.offerings.find_by(main: true) ||
      current_organization.offerings.create!(main: true)
  end

  def assign_account_manager_select_collections
    combined = account_managers_for_select
    @accountManagers = combined.map { |u| [u.email, u.id] }
    @accountManagersByName = combined.map { |u| [u.name, u.id] }
  end

  def set_current_organization
    @current_organization = resolve_current_organization
    Current.organization = @current_organization
    Current.user = current_user

    if user_signed_in? && @current_organization.nil?
      sign_out(current_user)
      redirect_to new_user_session_path, alert: "Your account is not assigned to an organization. Contact an administrator." and return
    end

    if user_signed_in? && !current_user.superadmin? && @current_organization
      session[:organization_id] = @current_organization.id
    end
  end

  def resolve_current_organization
    return nil unless user_signed_in?

    if current_user.superadmin?
      org = if session[:organization_id].present?
              Organization.find_by(id: session[:organization_id])
            end
      org = nil if org && !org.active?
      org || Organization.active.order(:name).first
    else
      current_user.primary_organization
    end
  end

  def check_and_refresh_quickbooks_token
    puts
    puts "====== AppControl QB TOKEN REFRESH MANUAL ======".red
    context = QuickbooksServiceContext.new(current_user, organization: current_organization)
    service = QuickbooksService.new(context)
    # service = QuickbooksService.new
    # service.refresh_token_if_expired # Turning off expired check for now
    service.refresh_token_force(context)
  end

  protected
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:position, :name, :email, :password, :password_confirmation, :role)
    end
    devise_parameter_sanitizer.permit(:sign_in) do |user_params|
      user_params.permit(:position, :name, :email, :password)
    end
    devise_parameter_sanitizer.permit(:account_update) do |user_params|
      user_params.permit(:position, :name, :email, :current_password, :password, :password_confirmation, :role, :position)
    end
  end

end
