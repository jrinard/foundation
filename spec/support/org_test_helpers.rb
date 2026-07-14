module OrgTestHelpers
  def sign_in_as(user, organization: nil)
    org = organization || user.primary_organization
    sign_in user
    post switch_organization_path, params: { organization_id: org.id } if user.superadmin? && org
  end

  def create_org_with_admin(name: "Acme Corp", pipeline: true)
    org = create(:organization, name: name, sales_pipeline_enabled: pipeline)
    org.provision_defaults!
    admin = create(:user, role: "admin")
    create(:organization_membership, user: admin, organization: org, role: "admin")
    [org, admin]
  end
end

RSpec.configure do |config|
  config.include OrgTestHelpers, type: :request
end
