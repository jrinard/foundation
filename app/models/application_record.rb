class ApplicationRecord < ActiveRecord::Base
  #OLDCRM had  self.abstract_class = true
  primary_abstract_class
end
