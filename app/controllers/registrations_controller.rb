class RegistrationsController < Devise::RegistrationsController
  def new
    redirect_to new_user_session_path, alert: "Sign up is invite-only. Contact your administrator."
  end

  def create
    redirect_to new_user_session_path, alert: "Sign up is invite-only. Contact your administrator."
  end

  protected

  def update_resource(resource, params)
    resource.update_with_password(params)
  end

end
