class Ability
  include CanCan::Ability

  CRM_MODELS = [
    Customer, Lead, List, Contact, Note, Offering, Stats, QbInvoice, DiscoveryBusiness,
    OutreachPlan, OutreachCampaign, OutreachEnrollment, OutreachActivity, OutreachTextMessage
  ].freeze

  ADMIN_ORG_MODELS = [
    SiteSetting, QuickbooksToken, OutreachSmsChannel
  ].freeze

  def initialize(user, organization = Current.organization)
    user ||= User.new
    @user = user
    @organization = organization

    if user.superadmin?
      can :manage, :all
      return
    end

    return unless organization.present? && user.member_of?(organization)

    grant_crm_access
    can :read, :settings

    return unless user.admin?

    grant_admin_access
  end

  private

  attr_reader :user, :organization

  def grant_crm_access
    CRM_MODELS.each do |model|
      can :manage, model, organization_id: organization.id
    end
  end

  def grant_admin_access
    ADMIN_ORG_MODELS.each do |model|
      can :manage, model, organization_id: organization.id
    end

    can :manage, :settings
    can :manage, :quickbooks if organization.quickbooks_enabled?

    can [:read, :create], User
    can [:update, :destroy], User do |target_user|
      target_user.organization_memberships.exists?(organization_id: organization.id)
    end
  end
end
