class CustomersController < ApplicationController
  include NavModuleRequired
  include OutreachCustomerLoading
  require_nav_module :leads

  load_and_authorize_resource
  # before_action :set_customer, only: [:show, :edit, :update, :destroy, :move]

    require 'will_paginate/array'

  def index
    @user = current_user

    ##* This is the list for Kanban
    @lists = List.rank(:row_order)
    ## This is used for the filter on the kanban
    # @accounts = User.where.not(role: "superadmin").order("created_at desc").pluck(:email, :id)


    assign_account_manager_select_collections

    

    ##* Kanban stat bar when filtered by account manager (excludes lists with label "excluded")
    if params[:user_id].present?
      @sales_person_id = User.find_by(id: params[:user_id])

      kanban_stats_scope = Customer.excluding_lists_opted_out_of_stats_bar(
        Customer.where(user_id: params[:user_id])
      )

      @filter_lead_count = kanban_stats_scope
        .where(onBoard: ['Lead on Board', 'Current on Board'])
        .count

      # Last 30 days — same scope (ignores customers sitting on stats-excluded columns)
      @filter_lead_count_last_30 = kanban_stats_scope.where("created_at >= ?", 30.days.ago).count

      start_of_month = Date.today.beginning_of_month
      end_of_month = Date.today.end_of_month
      @filter_lead_count_current_month = kanban_stats_scope.where(onBoard: ['Current Not on Board', 'Current on Board'] )
        .where(updated_at: start_of_month..end_of_month).count

      @filter_lead_count_total_recurring_monthly_charge = kanban_stats_scope
        .pluck(:recurring_monthly_charge)
        .map { |charge| charge.to_i }
        .sum
      @filter_lead_count_total_one_time_payment = kanban_stats_scope
        .pluck(:one_time_payment)
        .map { |charge| charge.to_i }
        .sum
    end


  

    ##* Global Stat
    ## Note this is just a total of all regardless of onBoard status
    @total_one_time_payment_all = Customer.excluding_lists_opted_out_of_stats_bar(Customer.all)
      .pluck(:one_time_payment)
      .map { |charge| charge.to_i }
      .sum

    @total_recurring_monthly_charge_all = Customer.excluding_lists_opted_out_of_stats_bar(Customer.all)
      .pluck(:recurring_monthly_charge)
      .map { |charge| charge.to_i }
      .sum

    @main_stats = Stats.where(main: true).order("created_at desc")
    if params[:selected_stat_id].present?
      @selected_stat = Stats.find(params[:selected_stat_id])
      @selected_stat_week_total_leads = Customer.adjusted_total_leads_by_week_for_stats_bar(@selected_stat)
    end

    # @import = Customer::Import.new

    def download_pdf
      send_file "#{Rails.root}/app/assets/docs/a-customers.csv", type: "application/pdf", x_sendfile: true
    end

    if (params[:sort_by])
      @potential_customers = Customer.potential_customers.includes(:contacts).order(params[:sort_by])
    else
      #Default is alphabetical
      @potential_customers = Customer.potential_customers.includes(:contacts).order('name asc')
    end

    @potential_customers = Customer.potential_customers.includes(:contacts)


    if (params[:l])
      @potential_customers = Customer.potential_customers.where("letter = ?", params[:l])
    end

    if params[:search]
      @potential_customers_search = Customer.potential_customers.includes(:contacts)
      
      #Textacular Searching
      #@searchResults = @potential_customers_search.where("name LIKE ?", "%#{params[:search].titleize}%")

      #PG_search for Customers
      @searchResults = @potential_customers_search.global_search_customers(params[:search])

      #PG_Global Search For Contacts
      @contacts = Contact.joins(:customer).where(customers: { archived: false })
      @searchResultsContacts = @contacts.global_search_contacts(params[:search])

    end

    if params[:id]
      @chosen_customer = Customer.find(params[:id])
      load_outreach_for_customer!(@chosen_customer) if outreach_enabled?
    end

    if params[:active]
      @chosen_customer.update(:active => true)
    end
    if params[:inactive]
      @chosen_customer.update(:active => false)
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
    @indiv_notes = Note.where("customer_id = ?", params[:id]).order("id ASC").limit(5)

    #Might be needed by home form
    @customer = Customer.new

  end #index end


# CUSTOMER IMPORT
  def import

    @import = Customer::Import.new customer_import_params
    if @import.save
      @last = Customer.last
      redirect_to root_path, notice: "Imported #{@import.imported_count} client(s)"
    else
      @customers = Customer.all
      @last = Customer.last
      redirect_to root_path, notice: "#{@import.imported_count} client(s) imported but #{@import.errors.count} client(s) were not, due to errors with your CSV file"
    end
  end

  def sort
    @customer = Customer.find(params[:id])
    @customer.update(row_order_position: params[:row_order_position], list_id: params[:list_id])
    head :no_content
  end


  def show
    @customer = Customer.find(params[:id])

    if params[:id]
      @chosen_customer = Customer.find(params[:id])
    end

  end

  def new
    @customer = Customer.new
    @lists = List.rank(:row_order)
    
    #TEMP Correct to limit
    # @accounts = User.where.not(role: "superadmin").order("created_at desc").pluck(:email, :id)

    assign_account_manager_select_collections

  end  
  

  def edit
    @customer = Customer.find(params[:id])
    #Hard setting 1 contact
    @contacts = @customer.contacts.limit(1).all
    #TEMP Correct to limit
    # @accounts = User.where.not(role: "superadmin").order("created_at desc").pluck(:email, :id)

    assign_account_manager_select_collections

    # @customer = Customer.find(params[:id])
    @indiv_notes = @customer.notes.where(:account_note => false).order(created_at: :desc)
    @note = Note.new
    @user = current_user
  end

  def existing_edit
    @customer = Customer.find(params[:id])

    @contacts = @customer.contacts.limit(1).first
    #TEMP Correct to limit
    # @accounts = User.where.not(role: "superadmin").order("created_at desc").pluck(:email, :id)

    assign_account_manager_select_collections
    @indiv_notes = Note.where(:account_note => false, :customer_id => params[:id]).order("id DESC")
    @lists = List.all.order("id asc").pluck(:name, :id)

  end

  def create
    @customer = Customer.new(customer_params)
    referrer = request.referrer
      if @customer.save
        log_last_stat

        #Use the referrer to see the location things came from /customers
        if referrer.present? && referrer.include?('customers')
          puts "=== Routing to Leads Page"
          render json: { redirect: customers_path }
          # format.json { render json: customers_path}
        elsif referrer.present? && referrer.include?('potentials')
            puts "=== Routing to Potential/The List Page"
            render json: { redirect: potentials_path }
            # format.json { render json: customers_path}
        else
          puts "=== Routing to Home Path with details"
          # format.json { render json: root_path}
          render json: { redirect: root_path }
        end

        # format.json { render json: { redirect: customers_path} }
        flash[:notice] = "Customer was successfully created."
        # format.html { redirect_to customers_path, notice: 'Customer was successfully created.' }
      else
        # format.html { render :new }
        # format.json { render json: root_path.errors, status: :unprocessable_entity }
      end

  end

  def update
    @customer = Customer.find(params[:id])
    puts "Received Parameters: #{params.inspect}"
    referrer = request.referrer
    if @customer.update(customer_params)

      #* Simplified so it stays in kanban or details page
        # if @customer.archived === false
        #   if @customer.active === true

                #Use the referrer to see the location things came from /customers
                if referrer.present? && referrer.include?('customers')
                  puts "=== Routing to Leads Page"
                  redirect_url = customers_path( user_id: @customer.user_id)
                  render json: { redirect: redirect_url }
                  # render json: { redirect: customers_path }
                  
                elsif referrer.present? && referrer.include?('potentials')
                    puts "=== Routing to The List Page"
                    render json: { redirect: potentials_path(:id => @customer, :view_notes => "view_notes") }
                else
                puts "=== Routing to Home Path"
                # redirect_to root_path
                # render json: { redirect: customers_path }
                render json: { redirect: customer_detail_path(@customer, view_notes: "view_notes") }
                end
              # else
              #   render json: { redirect: customers_path }
              #   flash[:notice] = "Customer updated!"
              # end

        # else @customer.archived === true
        #   puts "=== Routing to Archive Path"
        #   # redirect_to archived_index_path(:id => params[:subaction])
        #   render json: { redirect: archived_index_path(:id => params[:subaction]) }
        #   flash[:notice] = "Customer updated!"
        # end
    else
      flash[:notice] = "There was an error. Updating the customer."
      render :edit
    end
  end

  def destroy
    @customer = Customer.find(params[:id])
    referrer = request.referrer
    if @customer.destroy
        flash[:notice] = "Customer has been deleted!"
        #TODO json was not needed the redirect works in this case
        # #Use the referrer to see the location things came from /customers
        if referrer.present? && referrer.include?('customers')
          puts "=== Routing to Leads Page"
          # redirect_to customers_path
          render json: { redirect: customers_path } 
        elsif referrer.present? && referrer.include?('archived')
          puts "=== Routing to Archived"
          redirect_to archived_index_path
          # render json: { redirect: archived_index_path }
        elsif referrer.present? && referrer.include?('potentials')
          puts "=== Routing to The List Page"
          render json: { redirect: potentials_path }
        else
          puts "=== Routing to Home Path"
          redirect_to root_path
          # render json: { redirect: root_path }
        end
       
        # render json: { redirect: root_path }
    else
      flash[:notice] = "Error customer has NOT been deleted!"
      redirect_to root_path
      # render json: { redirect: root_path }
    end
  end

  def move
    @customer = Customer.find(params[:id])
    @customer.insert_at(params[:position].to_i)

    # Get the current value of the 'active' attribute
    # current_active = @customer.active
    # puts "===current_active".red
    # puts current_active

    # # Get the new value of 'active' from the params
    # new_active = ActiveRecord::Type::Boolean.new.cast(params[:active])
    # puts "===new_active".red
    # puts new_active

      parms = params[:active]
      puts "===parms".red
      puts parms

      if @customer.update(active: params[:active])
        puts "=== Update successful!"
      else
        puts "=== Update failed!"
        puts @customer.errors.full_messages
      end
    head :ok
  end

  private
  
  def set_customer
    @customer = Customer.find(params[:id])
  end

    def customer_import_params
      params.require(:customer_import).permit(:file)
    end

    def customer_params
      params.require(:customer).permit(:name, :letter, :domain, :email, :phone, :list_id,
                                        :position, :recurring_monthly_charge, :one_time_payment,
                                        :extra_notes, :sales_person,
                                        :active, :archived, :contract_start, :contract_end,
                                        :address, :city, :state, :zip, :email, :user_id,
                                        :followup, :last_note, :last_note_text,
                                        :quickbooks_customer_id,
                                        :sms_opt_in, :sms_opt_out_note,
                                        :sms_opt_in_source, :sms_opt_out_source,
                                        :sms_opt_in_at, :sms_opt_in_label,
                                        :active_proposal, :onBoard,
                                        contacts_attributes: [:id, :position, :firstname, :lastname, :phone, :phone2, :email, :note]
                                    )
    end

    DAYS_OF_WEEK = {
      "Mon" => :monday,
      "Tue" => :tuesday,
      "Wed" => :wednesday,
      "Thu" => :thursday,
      "Fri" => :friday,
      "Sat" => :saturday,
      "Sun" => :sunday
    }.freeze

    def log_last_stat
      today = Date.today
      week_start_date = today.beginning_of_week(:monday)
      week_end_date = week_start_date.end_of_week(:sunday)
      date_info = {
        day_of_week_text: today.strftime("%a"),
        month_by_text: today.strftime("%B"),
        month_by_number: today.month,
        year_by_text: today.strftime("%Y"),
        year_by_number: today.year,
        week_start_by_text: week_start_date.strftime("%-m/%-d/%y"),
        week_start_by_date: week_start_date,
        week_end_by_text: week_end_date.strftime("%-m/%-d/%y"),
        week_end_by_date: week_end_date
      }

      last_main_stat = Stats.where(main: true).order(created_at: :desc).first
      return unless last_main_stat

      case date_info[:day_of_week_text]
      when "Mon"
        last_main_stat.update(monday: (last_main_stat.monday || 0) + 1)
      when "Tue"
        last_main_stat.update(tuesday: (last_main_stat.tuesday || 0) + 1)
      when "Wed"
        last_main_stat.update(wednesday: (last_main_stat.wednesday || 0) + 1)
      when "Thu"
        last_main_stat.update(thursday: (last_main_stat.thursday || 0) + 1)
      when "Fri"
        last_main_stat.update(friday: (last_main_stat.friday || 0) + 1)
      when "Sat"
        last_main_stat.update(saturday: (last_main_stat.saturday || 0) + 1)
      when "Sun"
        last_main_stat.update(sunday: (last_main_stat.sunday || 0) + 1)
      end

      last_main_stat.update(
        total_leads_and_customers: (last_main_stat.total_leads_and_customers || 0) + 1,
        total_leads_on_board: (last_main_stat.total_leads_on_board || 0) + 1,
        month_by_text: date_info[:month_by_text],
        month_by_number: date_info[:month_by_number],
        year_by_text: date_info[:year_by_text],
        year_by_number: date_info[:year_by_number],
        week_start_by_text: date_info[:week_start_by_text],
        week_start_by_date: date_info[:week_start_by_date],
        week_end_by_text: date_info[:week_end_by_text],
        week_end_by_date: date_info[:week_end_by_date]
      )
    end

end
