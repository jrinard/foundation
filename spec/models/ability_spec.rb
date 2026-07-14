require "rails_helper"

RSpec.describe Ability do
  let(:org) { create(:organization, :with_pipeline_defaults) }
  let(:other_org) { create(:organization, :with_pipeline_defaults, name: "Other Org") }

  describe "org admin" do
    let(:admin) { create(:user, role: "admin") }

    before do
      create(:organization_membership, user: admin, organization: org, role: "admin")
    end

    it "can manage CRM records in their org" do
      ability = Ability.new(admin, org)
      expect(ability.can?(:manage, Customer.new(organization_id: org.id))).to be true
    end

    it "cannot manage CRM records in another org" do
      ability = Ability.new(admin, org)
      expect(ability.can?(:manage, Customer.new(organization_id: other_org.id))).to be false
    end

    it "cannot manage organizations" do
      ability = Ability.new(admin, org)
      expect(ability.can?(:manage, Organization)).to be false
    end
  end

  describe "superadmin" do
    let(:superadmin) { create(:user, :superadmin) }

    before do
      create(:organization_membership, user: superadmin, organization: org)
    end

    it "can manage everything" do
      ability = Ability.new(superadmin, org)
      expect(ability.can?(:manage, :all)).to be true
    end
  end

  describe "member user" do
    let(:member) { create(:user, :member) }

    before do
      create(:organization_membership, user: member, organization: org, role: "user")
    end

    it "can manage CRM records but not settings admin" do
      ability = Ability.new(member, org)
      expect(ability.can?(:manage, Customer.new(organization_id: org.id))).to be true
      expect(ability.can?(:read, :settings)).to be true
      expect(ability.can?(:manage, :settings)).to be false
    end
  end
end
