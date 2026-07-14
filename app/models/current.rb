class Current < ActiveSupport::CurrentAttributes
  attribute :organization
  attribute :user

  def organization_id
    organization&.id
  end
end
