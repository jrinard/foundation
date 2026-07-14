class OrganizationSwitchesController < ApplicationController
  def create
    organization = Organization.find(params[:organization_id])

    unless organization.active?
      redirect_back fallback_location: root_path, alert: "That organization is deactivated."
      return
    end

    unless current_user.superadmin? || current_user.member_of?(organization)
      redirect_back fallback_location: root_path, alert: "You cannot access that organization."
      return
    end

    session[:organization_id] = organization.id
    redirect_back fallback_location: root_path, notice: "Switched to #{organization.name}."
  end
end
