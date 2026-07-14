require "rails_helper"

RSpec.describe "Organizations access", type: :request do
  let!(:org) { create(:organization, :with_pipeline_defaults) }
  let!(:superadmin) { create(:user, :superadmin, email: "super@test.com") }
  let!(:org_admin) { create(:user, role: "admin", email: "orgadmin@test.com") }

  before do
    create(:organization_membership, user: superadmin, organization: org)
    create(:organization_membership, user: org_admin, organization: org, role: "admin")
  end

  describe "Organizations tab" do
    it "allows superadmin to list organizations" do
      sign_in_as superadmin, organization: org
      get organizations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(org.name)
    end

    it "blocks org admin from organizations index" do
      sign_in org_admin
      get organizations_path
      expect(response).to redirect_to(root_path)
    end

    it "allows superadmin to create an organization" do
      sign_in_as superadmin, organization: org
      expect {
        post organizations_path, params: {
          organization: { name: "New Partner Org", sales_pipeline_enabled: true }
        }
      }.to change(Organization, :count).by(1)

      new_org = Organization.find_by(name: "New Partner Org")
      expect(new_org).to be_present
      expect(new_org.active?).to be true
      expect(new_org.lists.count).to be >= 1
    end

    it "allows superadmin to rename an organization" do
      sign_in_as superadmin, organization: org

      patch rename_organization_path(org), params: {
        organization: { name: "Renamed Org", slug: "renamed-org" }
      }

      expect(response).to redirect_to(organization_path(org))
      org.reload
      expect(org.name).to eq("Renamed Org")
      expect(org.slug).to eq("renamed-org")
    end

    it "deactivates an organization instead of deleting it" do
      other_org = create(:organization, :with_pipeline_defaults, name: "Archive Me Org")
      sign_in_as superadmin, organization: org

      expect {
        delete organization_path(other_org)
      }.not_to change(Organization, :count)

      expect(other_org.reload.active?).to be false
      expect(Organization.active.find_by(id: other_org.id)).to be_nil

      get organizations_path
      expect(response.body).not_to include('>Archive Me Org<')
    end
  end

  describe "User org assignment" do
    let!(:target_user) { create(:user, :member, email: "member@test.com") }

    before do
      create(:organization_membership, user: target_user, organization: org, role: "user")
    end

    it "allows superadmin to reassign user to another org via edit form" do
      other_org = create(:organization, :with_pipeline_defaults, name: "Reassign Target")
      sign_in_as superadmin, organization: org

      patch user_path(target_user), params: {
        user: { name: target_user.name, email: target_user.email, role: "user", organization_id: other_org.id }
      }

      expect(response).to redirect_to(users_path)
      expect(target_user.reload.primary_organization).to eq(other_org)
    end

    it "does not expose organization select on user edit for org admin" do
      sign_in org_admin
      get edit_user_path(org_admin)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="user[organization_id]"')
    end
  end

  describe "Invite-only registration" do
    it "blocks public sign-up" do
      get new_user_registration_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
