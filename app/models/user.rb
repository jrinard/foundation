class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :customers
  has_many :contacts
  has_many :notes


  define_model_callbacks :user, :only => [:before, :after]


  def remember_me
    true
  end


  def update_with_password(params, *options)
      current_password = params.delete(:current_password)

      if params[:password].blank?
        params.delete(:password)
        params.delete(:password_confirmation) if params[:password_confirmation].blank?
      end

      result = if params[:password].blank? || valid_password?(current_password)
        update(params, *options)
      else
        self.assign_attributes(params, *options)
        self.valid?
        self.errors.add(:current_password, current_password.blank? ? :blank : :invalid)
        false
      end

      clean_up_passwords
      result
  end

### ROLES

    def superadmin?
      self.role === "superadmin"
    end

    def admin?
      self.role === "admin"
    end

    def manager?
      self.role === "manager"
    end

    def user?
      self.role === "user"
    end

    def primary_membership
      organization_memberships.first
    end

    def primary_organization
      organizations.first
    end

    def member_of?(organization)
      return false if organization.nil?

      superadmin? || organization_memberships.exists?(organization_id: organization.id)
    end

   ROLES = %i[user manager admin superadmin]

   def roles=(roles)
     roles = [*roles].map { |r| r.to_sym }
     self.roles_mask = (roles & ROLES).map { |r| 2**ROLES.index(r) }.inject(0, :+)
   end

   def roles
     ROLES.reject do |r|
       ((roles_mask.to_i || 0) & 2**ROLES.index(r)).zero?
     end
   end

   def has_role?(role)
     roles.include?(role)
   end

######

   def self.from_omniauth(auth)
       user = User.where(:provider => auth.provider, :uid => auth.uid).first
       if user
         return user
       else
         registered_user = User.where(:email => auth.info.email).first
         if registered_user
           return registered_user
         else
           where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
             user.provider = auth.provider
             user.uid = auth.uid
             user.email = auth.info.email
             # user.firstname = auth.info.first_name
             # user.lastname = auth.info.last_name
             # user.avatar = auth.info.image
             user.password = Devise.friendly_token[0, 20]
           end
         end
       end
     end


     def self.find_for_google_oauth2(access_token, signed_in_resource=nil)
       data = access_token.info
       user = User.where(:provider => access_token.provider, :uid => access_token.uid).first
       if user
         return user
       else
         registered_user = User.where(:email => access_token.info.email).first
         if registered_user
           return registered_user
         else #google oauth user creation
           user = User.create(
                              # name: data["name"],
                              provider: access_token.provider,
                              email: data["email"],
                             #  firstname: data["first_name"],
                             #  lastname: data["last_name"],
                             #  avatar: data["image"],
                              # accountnumber: "2084231710",
                              role: "admin",
                              uid: access_token.uid,
                              password: Devise.friendly_token[0, 20],
           )
         end
       end
     end

     def self.new_with_session(params, session)
       super.tap do |user|
         if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
           user.email = data["email"] if user.email.blank?
         end
       end
     end

   end
