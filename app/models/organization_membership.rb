class OrganizationMembership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :user_id, uniqueness: { scope: :organization_id }

  # v1: org assignment only. Authorization uses User#role (user / admin / superadmin).
  # The `role` column remains in the schema (default "user") but is not used.
end
