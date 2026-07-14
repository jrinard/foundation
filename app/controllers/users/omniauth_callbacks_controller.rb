class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def google_oauth2
    @user = User.find_for_google_oauth2(request.env["omniauth.auth"], current_user)
    # set_service
    if @user.persisted?
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
      sign_in_and_redirect @user, :event => :authentication
    else
      session["devise.google_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  # before_action :set_service
  # before_action :set_user
  attr_reader :service, :user

  #Used to create a google service
  # def goog
  #   handle_auth "Google"
  # end

  def facebook
    handle_auth "Facebook"
  end

  private

  def handle_auth(kind)
    set_user
    set_service
    if service.present?# UPDATE TOKEN
      service.update(service_attrs)  
    else # Service is NOT present CREATE one
      user.services.create(service_attrs)
    end

    if user_signed_in? # Basic Confirmation
      flash[:notice] = "Your #{kind} account was connected."
      redirect_to facebooks_path
    else
      sign_in_and_redirect user, event: :authentication
      set_flash_message :notice, :success, kind: kind
    end
  end

## 1
  def auth
    request.env['omniauth.auth']

  end
## 2
  def set_service
    puts "--- Service Setting ggggggggg ---"
    # @service = Service.where(provider: auth.provider, uid: auth.uid ).first #@service = Service.where("user_id = ?", current_user.id).last
    @service = Service.where(provider: auth.provider, uid: auth.uid, user_id: current_user.id).first
    
  end
## 2
  def set_user
    if user_signed_in?
      @user = current_user
      puts "--- Omni Current User Set ---"
    else service.present?
      @user = service.user
      puts "--- Omni Service Already Set ---"
    # elsif User.where(email: auth.info.email).any?
    #   # 5. User is logged out and they login to a new account which doesn't match their old one
      # flash[:alert] = "An account with this email already exists. Please sign in with that account before connecting your #{auth.provider.titleize} account."
    #   redirect_to new_user_session_path
    end
  end
## 5
  def service_attrs
    expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
    {
        provider: auth.provider,
        uid: auth.uid,
        expires_at: expires_at,
        access_token: auth.credentials.token,
        access_token_secret: auth.credentials.secret,
    }
  end

  # def failure
  #   redirect_to root_path
  # end

end
