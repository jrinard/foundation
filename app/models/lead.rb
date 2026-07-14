class Lead < ApplicationRecord
  include OrganizationScoped

    #, optional: true may be depreciated
    belongs_to :customer, optional: true
    belongs_to :contact, optional: true
    belongs_to :list
    # has_one :contact
    
  
    accepts_nested_attributes_for :customer
    accepts_nested_attributes_for :contact
end
  