require "rails_helper"

RSpec.describe "Foundation QA flows", type: :request do
  let!(:org) { create(:organization, :with_pipeline_defaults, name: "Pipeline Org") }
  let!(:admin) { create(:user, role: "admin", email: "pipeline-admin@test.com") }
  let!(:prospect_list) { org.lists.find_by(default_for_new_leads: true) || org.lists.first }

  before do
    create(:organization_membership, user: admin, organization: org, role: "admin")
  end

  describe "pipeline" do
    it "loads kanban for pipeline-enabled org" do
      sign_in admin
      get customers_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Prospect").or include(prospect_list.name)
    end

    it "creates a lead on the pipeline" do
      sign_in admin
      expect {
        post leads_path, params: {
          lead: { name: "QA New Lead", phone: "2085550100", email: "lead@example.com" }
        }
      }.to change(Customer, :count).by(1)

      lead = Customer.order(:id).last
      expect(lead.organization_id).to eq(org.id)
      expect(lead.name).to eq("QA New Lead")
    end

    it "moves a customer between pipeline stages" do
      customer = create(:customer, :on_pipeline, organization: org, list: prospect_list, name: "Movable Lead")
      next_list = org.lists.where.not(id: prospect_list.id).order(:row_order).first

      sign_in admin
      put sort_customer_path(customer), params: { list_id: next_list.id, row_order_position: 0 }
      expect(response).to have_http_status(:no_content)
      expect(customer.reload.list_id).to eq(next_list.id)
    end
  end

  describe "notes" do
    let!(:customer) { create(:customer, :on_pipeline, organization: org, name: "Noted Customer") }

    it "adds a note to a customer profile" do
      sign_in admin
      expect {
        post notes_path, params: {
          note: { text: "QA follow-up note", customer_id: customer.id, user_id: admin.id }
        }
      }.to change(Note, :count).by(1)

      note = Note.order(:id).last
      expect(note.organization_id).to eq(org.id)
      expect(note.text).to eq("QA follow-up note")
    end
  end

  describe "offerings" do
    let!(:main_offering) { org.offerings.find_by(main: true) || create(:offering, :main_template, organization: org) }
    let!(:customer) { create(:customer, :on_pipeline, organization: org, name: "Offering Customer", active: true) }

    before do
      main_offering.update!(offering_1_name: "Premium Plan", offering_1_active: true)
    end

    it "loads settings with main offerings template" do
      sign_in admin
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(org.offerings.where(main: true)).to exist
    end
  end

  describe "non-pipeline org" do
    let!(:ops_org) { create(:organization, :with_pipeline_defaults, :no_pipeline, name: "Ops Only Org") }
    let!(:ops_admin) { create(:user, role: "admin", email: "ops-admin@test.com") }

    before do
      create(:organization_membership, user: ops_admin, organization: ops_org, role: "admin")
    end

    it "redirects org admin away from kanban when pipeline disabled" do
      sign_in ops_admin
      get customers_path
      expect(response).to redirect_to(home_index_path)
    end

    it "root sends pipeline-disabled org to current clients" do
      sign_in ops_admin
      get root_path
      expect(response).to redirect_to(home_index_path)
    end
  end
end
