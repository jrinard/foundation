json.extract! customer, :id, :companyname, :firstname, :lastname, :phone, :notes, :timestamps, :created_at, :updated_at
json.url customer_url(customer, format: :json)
