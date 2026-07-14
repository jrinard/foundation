class QuickbooksServiceContext
  attr_reader :current_user, :organization, :integration

  def initialize(current_user, organization: Current.organization)
    @current_user = current_user
    @organization = organization
    @integration = QuickbooksToken.integration_for(organization) if organization
  end
end
