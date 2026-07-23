class Customer < ApplicationRecord
  include OrganizationScoped

  acts_as_list
  belongs_to :user, optional: true
  has_many :contacts, -> { order(updated_at: :desc) }
  accepts_nested_attributes_for :contacts
  has_many :notes
  has_many :offerings
  has_many :qb_invoices
  has_many :discovery_businesses
  has_many :outreach_enrollments, dependent: :destroy

  def linked_discovery_business
    discovery_businesses.order(updated_at: :desc).first
  end
  # validates :intake, presence: true  ###!!! Caused Leads to not create

  #part of sortable
  belongs_to :list, optional: true
  include RankedModel
  ranks :row_order, with_same: :list_id


  scope :not_archived, -> { where(:archived => false) }
  scope :has_list, -> { where.not(list_id: nil) }
  scope :current_customers, -> { where(:active => true).not_archived }
  # scope :current_customers_with_no_proposals, -> { where(:active => true, :active_proposal => false).not_archived }
  scope :potential_customers, -> { where(active: false, onBoard: "The List").not_archived }
  scope :lead_customers, -> { where(onBoard: ["Lead on Board", "Current on Board"]).where.not(list_id: nil).not_archived }

  #Mainly used for stats in banav bar
  # scope :lead_customers, -> { where(:archived => false ).has_list } 
  scope :archived_customers, -> { where(archived: true).order(name: :asc) }

  # Kanban header stats: omit customers on lists opted out via list.label ("excluded", or legacy "false").
  # PostgreSQL: plain `NOT IN` drops rows where list_id IS NULL; keep unlisted customers in stats.
  def self.excluding_lists_opted_out_of_stats_bar(relation = all)
    excluded_ids = List.where(label: ["excluded", "false"]).ids
    return relation if excluded_ids.empty?

    t = relation.klass.table_name
    relation.where("#{t}.list_id IS NULL OR #{t}.list_id NOT IN (?)", excluded_ids)
  end

  # Stats row running total, minus customers created that week who sit on stats-excluded lists.
  def self.adjusted_total_leads_by_week_for_stats_bar(stat)
    return 0 unless stat.is_a?(Stats)

    stored = stat.total_leads_and_customers.to_i
    return stored unless stat.week_start_by_date.present? && stat.week_end_by_date.present?

    range = stat.week_start_by_date.beginning_of_day..stat.week_end_by_date.end_of_day
    excluded_ids = List.where(label: ["excluded", "false"]).ids
    deduct = excluded_ids.empty? ? 0 : Customer.where(created_at: range, list_id: excluded_ids).count
    [stored - deduct, 0].max
  end

  include PgSearch

  #PG_Search is a newer version of search instead of textacular
  pg_search_scope :global_search_customers, against: [
  :name, :letter, :domain, :email, :phone,
  :contract_start, :contract_end,
  :address, :city, :state, :zip, :email, :user_id
  ],  using: { tsearch: { prefix: true } }

# When an event is updated check the status that it is and make sure the list_id is nil or not
# The idea is when an event moves from lead to current its "active" value becomes true soo
# We have to make list_id nil to get it out of the leads

  # after_update :check_to_move_away_from_lead
  after_update :boardCheck
  after_create :boardCheck
  before_destroy :reopen_linked_discovery_businesses!

  #CUSTOMER IMPORTING
    # def self.import(file, list_id, user_id)
    def self.import(file)
      counter = 0
      CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
        # customer = Customer.assign_from_row(row, list_id, user_id)
        customer = Customer.assign_from_row(row)
        if customer.save
          counter += 1
        else
          puts "#{customer.companyname} = #{customer.errors.full_messages.join(",")}"
        end
      end
      counter
    end

    #CUSTOMER IMPORTING READING ROWS
    # def self.assign_from_row(row,list_id,user_id)
    def self.assign_from_row(row)
      # customer = Customer.where(phone: row[:phone],:list_id => list_id).first_or_initialize
      customer = Customer.where(name: row[:name]).first_or_initialize
      # customer = Customer.where(phone: row[:phone]).create
      customer.assign_attributes row.to_hash.slice(:domain, :phone, :email,
                                                   :active, :archived,
                                                   :extra_notes, :contract_start, :contract_end,
                                                   :address, :city, :state, :zip, :email, :monthtomonth,
                                                  :quickbooks_customer_id, :recurring_monthly_charge, :one_time_payment, :user_id)
      # customer.update(:list_id => list_id,:user_id => user_id)
      customer

      # # after contact creation find the customer that
      # # matches the customer_connect field then assign the id from the customer back to the contact
      # contact_last = contact.last
      # customer_connect = contact_last.customer_connect # customer_connect will match companyname
      # cus = Customer.where(name: customer_connect) #name is the company name
      # contact_last.update(:customer_id => cus.id) #assigning id from found customer back to contact
    end

    before_save :save_letter #:titleize_customer 

     def save_letter
      if self.name != nil
      self.letter = self.name[0,1]
      end
    end

    # def titleize_customer
    #   if self.name != nil
    #     self.name = self.name.capitalize
    #   end
    #   if self.name != nil
    #   self.letter = self.name[0,1]
    #   end
    # end


  def self.search(search)
    s = search.downcase.capitalize
    where("name LIKE ?", "%#{s}%")
  end

  def self.search_phone(search)
    s = search.downcase.capitalize
    where("phone LIKE ?", "%#{s}%")
  end
  paginates_per 100

  # Activity / reports: followup select values are day counts as strings ("30" = 1 month, etc.)
  FOLLOWUP_CADENCE_KEYS = %w[30 60 90 120 150 180 365].freeze

  def followup_cadence_days
    d = followup.to_s.to_i
    d.positive? ? d : nil
  end

  # True when a followup cadence is set and last qualifying activity is missing or older than that cadence.
  def qualifying_activity_past_followup?(last_activity_at)
    days = followup_cadence_days
    return false unless days
    return true if last_activity_at.blank?
    t = if last_activity_at.respond_to?(:in_time_zone)
          last_activity_at.in_time_zone
        else
          Time.zone.parse(last_activity_at.to_s)
        end
    t < days.days.ago
  end

    private

    def reopen_linked_discovery_businesses!
      discovery_businesses.update_all(
        status: DiscoveryBusiness::STATUS_DISCOVERY,
        customer_id: nil,
        updated_at: Time.current
      )
    end

    def boardCheck

      #* Make Lead
      if self.onBoard === 'Lead on Board' && self.list_id === nil
        puts 
        puts "=== Make Lead - Add list and active false".green
        puts 
        first_list_id = List.default_for_new_leads_id
        update_column(:list_id, first_list_id)
        update_column(:active, false)
        update_column(:archived, false)
      # #* Stays Lead 
      elsif self.onBoard === 'Lead on Board' && self.list_id != nil
        update_column(:active, false)
        update_column(:archived, false)
        puts 
        puts "=== Stays Lead - Keep list and active false".green
        puts 
      #* Make Current on the Board
      elsif self.onBoard === 'Current on Board' && self.list_id === nil
        first_list_id = List.default_for_new_leads_id
        update_column(:list_id, first_list_id)
        update_column(:active, true)
        update_column(:archived, false)
        puts 
        puts "=== Make Current on the Board - Add list and active true".green
        puts 
     #* Current on the Board and staying on the board - ???
      elsif self.onBoard === 'Current on Board' && self.list_id != nil
        update_column(:active, true) 
        update_column(:archived, false)
        puts 
        puts "=== Current on the Board and staying on the board - Keep list and active true".green
        puts 
      #* Is Current and NOT on board
      elsif self.onBoard === 'Current Not on Board'
        update_column(:list_id, nil)
        update_column(:active, true) 
        update_column(:archived, false)
        puts 
        puts "=== Is Current and NOT on board - Off List and active true".green
        puts
      elsif self.onBoard === 'The List'
        update_column(:list_id, nil)
        update_column(:active, false) 
        update_column(:archived, false)
        puts 
        puts "=== The List - archived false - list nil -active false".green
        puts
      elsif self.onBoard === 'Archive'
        update_column(:archived, true)
        update_column(:list_id, nil)
        puts 
        puts "=== Archive it!".green
        puts 
      else
        puts
        puts "=== Error Customer fell through board check - Making Lead on Board".red
        first_list_id = List.default_for_new_leads_id
        update_column(:list_id, first_list_id)
        update_column(:active, false)
        update_column(:archived, false)
        update_column(:onBoard, "Lead on Board")
        puts "self.onBoard"
        puts self.onBoard     
        puts "self.list_id"
        puts self.list_id    
        puts "self.active"
        puts self.active
        puts
      end

      #Off to try avoid duplicates
      # log_last_stat

    end

    # DAYS_OF_WEEK = {
    #   "Mon" => :monday,
    #   "Tue" => :tuesday,
    #   "Wed" => :wednesday,
    #   "Thu" => :thursday,
    #   "Fri" => :friday,
    #   "Sat" => :saturday,
    #   "Sun" => :sunday
    # }.freeze

    # def log_last_stat
    #     today = Date.today
    #     week_start_date = today.beginning_of_week(:monday)
    #     week_end_date = week_start_date.end_of_week(:sunday)
    #     date_info = {
    #       day_of_week_text: today.strftime("%a"),        # "Mon", "Tue", etc.
    #       month_by_text: today.strftime("%B"),           # "January", "February", etc.
    #       month_by_number: today.month,                  # 1, 2, ..., 12
    #       year_by_text: today.strftime("%Y"),            # "2024", "2025", etc.
    #       year_by_number: today.year,                    # 2024, 2025, etc.
    #       week_start_by_text: week_start_date.strftime("%-m/%-d/%y"), # Format: "5/20/24"
    #       week_start_by_date: week_start_date,          # Date object for start of the week
    #       week_end_by_text: week_end_date.strftime("%-m/%-d/%y"),     # Format: "5/26/24"
    #       week_end_by_date: week_end_date               # Date object for end of the week
    #     }
  
    #   puts 
    #   puts "=== Start Stat Update".red
    #   last_main_stat = Stats.where(main: true).order(created_at: :desc).first
    #   puts last_main_stat.created_at
    #   puts "date_info".red
    #   puts date_info
    #   puts "day_of_week_key".red
    #   day_of_week_key = DAYS_OF_WEEK[date_info[:day_of_week_text]]
    #   puts day_of_week_key
    #   if last_main_stat

    #     case date_info[:day_of_week_text]
    #     when "Mon"
    #       last_main_stat.update(monday: (last_main_stat.monday || 0) + 1)
    #     when "Tue"
    #       last_main_stat.update(tuesday: (last_main_stat.tuesday || 0) + 1)
    #     when "Wed"
    #       last_main_stat.update(wednesday: (last_main_stat.wednesday || 0) + 1)
    #     when "Thu"
    #       last_main_stat.update(thursday: (last_main_stat.thursday || 0) + 1)
    #     when "Fri"
    #       last_main_stat.update(friday: (last_main_stat.friday || 0) + 1)
    #     when "Sat"
    #       last_main_stat.update(saturday: (last_main_stat.saturday || 0) + 1)
    #     when "Sun"
    #       last_main_stat.update(sunday: (last_main_stat.sunday || 0) + 1)
    #     end

    #     last_main_stat.update(
    #       total_leads_and_customers: (last_main_stat.total_leads_and_customers || 0) + 1,  
    #       total_leads_on_board: (last_main_stat.total_leads_on_board || 0) + 1,           
    #       # day_of_week_text: date_info[:day_of_week_text],            
    #       month_by_text: date_info[:month_by_text],
    #       month_by_number: date_info[:month_by_number],
    #       year_by_text: date_info[:year_by_text],
    #       year_by_number: date_info[:year_by_number],
    #       week_start_by_text: date_info[:week_start_by_text],   
    #       week_start_by_date: date_info[:week_start_by_date],           
    #       week_end_by_text: date_info[:week_end_by_text],  
    #       week_end_by_date: date_info[:week_end_by_date],   
 
    #     )
    #     puts "=== Last Stats Record: #{last_main_stat.inspect}".red
    #   else
    #     puts "=== No Stats record found where main is true".red
    #   end
    # end
    
    # #Only used on details page to allow a bypass around leads ##TODO Proposal
    # def check_to_make_active
    #   if self.active === false && self.list_id === nil
    #     # update_column(:active, true)
    #     # update_column(:onBoard, 'Current Not on Board')
    #     puts "=== Customer made on details page".red
    #   end
    # end

end
