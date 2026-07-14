
  class LeadsController < ApplicationController
    include NavModuleRequired
    require_nav_module :leads

    load_and_authorize_resource class: Lead, only: [:create]

    def new_custom_lead
      @lead = Lead.new
      assign_account_manager_select_collections
      @lists = List.all.order("id asc").pluck(:name, :id)
      @default_list_id = List.default_for_new_leads_id
      @customers = Customer.all
      @initial_query = params[:initial_query]
      render "leads/new-lead"
    end

    def new
      @lead = Lead.new
      assign_account_manager_select_collections
      @lists = List.all.order("id asc").pluck(:name, :id)
      @default_list_id = List.default_for_new_leads_id
      # @customers = Customer.all
      puts "@lists in 'new' action: #{@lists}".green
    end
  
    def create
      @accounts = User.where.not(role: "superadmin").order("created_at desc").pluck(:email, :id)
      assign_account_manager_select_collections
      #May not be using
      @accounts ||= [[User.last.email, User.last.id]] if User.any?
      @lists = List.all.order("id asc").pluck(:name, :id)
      puts "@lists in 'create' action: #{@lists}".green
    
      @lead = Lead.new(lead_params)

      puts "=== Customer".green
      puts "@Customer.name = #{@lead.name}".green
      puts "@Customer.list_id = #{@lead.list_id}".green
      puts "@Customer.user_id = #{@lead.user_id}".green
  
      @customer = Customer.create(
        name: @lead.name,
        domain: @lead.domain,
        phone: @lead.phone,
        email: @lead.email,
        active: false,
        user_id: @lead.user_id, #@lead.user_id
        sales_person: @lead.sales_person, #@lead.user_id
        list_id: @lead.list_id.presence || List.default_for_new_leads_id, #@lead.list_id,
        one_time_payment: @lead.one_time_payment,
        recurring_monthly_charge: @lead.recurring_monthly_charge,
        active_proposal: false, ##When a lead is made put it on the kanban
        onBoard: @lead.onBoard
      )

      puts "=== Contact".green
      puts "@Contact FirstName = #{@lead.firstname}".green
      puts "@Customer ID = #{@customer.id}".green
      puts "recurring_monthly_charge = #{@customer.recurring_monthly_charge}".green
      puts "one_time_payment = #{@customer.one_time_payment}".green
  
      # Create a new contact using the data from the 'leads' table
      @contact = Contact.create(
        firstname: @lead.firstname,
        lastname: @lead.lastname,
        phone: @lead.contact_phone,
        email: @lead.contact_email,
        customer_id: @customer.id  # Assign the customer to the contact
      )

      puts "Contact ID = #{@contact.id}".green


      @test = @contact.inspect
      puts "== @test".green
      puts @test.inspect

      # Assign the contact to the lead
      # @lead.customer = @customer
      # @lead.contact = @contact

  
      if @customer.save
        log_last_stat_lead
        render json: { redirect: customers_path }
        flash[:notice] = "Lead, customer, and contact created successfully."
      else
        flash.now[:alert] = "Error creating lead. Please fix the following issues:"
        flash.now[:lead_errors] = @lead.errors.full_messages
        render :new
      end
    end
  
    private
  
    def lead_params
      params.require(:lead).permit(
        :list_id,
        :name,
        :domain,
        :email,
        :phone,
        :active,
        :user_id,
        :sales_person,
        :one_time_payment,
        :recurring_monthly_charge,
        :onBoard,
  
        :firstname,
        :lastname,
        :contact_phone,
        :contact_email,
        :customer_id,
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

    def log_last_stat_lead
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
  