class Contact < ApplicationRecord
  include OrganizationScoped

  belongs_to :customer

  before_validation :assign_organization_from_customer, on: :create

  private

  def assign_organization_from_customer
    self.organization_id ||= customer&.organization_id || Current.organization_id
  end

  public


include PgSearch

#Searching Contacts
pg_search_scope :global_search_contacts, against: 
[:position, :firstname, :lastname, :phone, :phone2, :email, :note ],  using: { tsearch: { prefix: true } }
 

### NEEDS REVAMP

  #CUSTOMER IMPORTING
  def self.import(file, list_id, user_id)
    counter = 0
    CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
      customer = Customer.assign_from_row(row, list_id, user_id)
      if customer.save
        counter += 1
      else
        puts "#{customer.firstname} = #{customer.errors.full_messages.join(",")}"
      end
    end
    counter
  end

  #CUSTOMER IMPORTING READING ROWS
  def self.assign_from_row(row,list_id,user_id)
    customer = Customer.where(phone: row[:phone],:list_id => list_id).first_or_initialize
    # customer = Customer.where(phone: row[:phone]).create
    customer.assign_attributes row.to_hash.slice(:firstname, :lastname, :companyname)
    customer.update(:list_id => list_id,:user_id => user_id)
    customer
  end




  before_save :titleize_contact
  def titleize_contact
    if self.firstname != nil
      self.firstname = self.firstname.titleize
    end
    if self.lastname != nil
      self.lastname = self.lastname.titleize
    end
  end


end
