require 'csv'

class Customer::Import
  include ActiveModel::Model
  # attr_accessor :file, :list_id, :user_id, :imported_count
  attr_accessor :file, :imported_count

  def process!
    @imported_count = 0
    CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row| #was filename instead of file.path
      # customer = Customer.assign_from_row(row, list_id, user_id)
      customer = Customer.assign_from_row(row)
      if customer.save
        @imported_count += 1
      else
        # errors.add(:base, :blank, message: "cannot be nil") if phone.nil?
        errors.add :base, "Line #{$.} - #{customer.errors.full_messages.join(",")}"
      end
    end
  end

  def save
    process!
    errors.none?
  end
end
