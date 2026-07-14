class RootController < ApplicationController
  skip_authorization_check only: :show

  def show
    redirect_to org_default_path
  end
end
