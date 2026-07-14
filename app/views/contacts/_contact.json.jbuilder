json.extract! contact, :id, :position, :firstname, :lastname, :phone, :phone2, :email, :note, :,
json.url contact_url(contact, format: :json)
