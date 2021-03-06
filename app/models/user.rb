require 'digest/sha1'
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  #devise :database_authenticatable, :registerable,
  #       :recoverable, :rememberable, :validatable
  
  devise :database_authenticatable, :trackable, :validatable, :lockable, :timeoutable, :authentication_keys => [:login]

  validates :login, :uniqueness => { :case_sensitive => false} #, :format => { ... } # etc.
  #cancancan
  ROLES = %i[guest author editor admin superadmin]

  # Authorization plugin
 # acts_as_authorized_user
 # acts_as_authorizable

  #validates_presence_of :email
  #validates_presence_of :password, :if => :require_password?
  #validates_presence_of :password_confirmation, :if => :require_password?
  #validates_length_of :password, :within => 4..40, :if => :require_password?
  #validates_confirmation_of :password, :if => :require_password?
  #validates_length_of :email, :within => 3..100
  #validates_uniqueness_of :email, :case_sensitive => false
  #validates_inclusion_of :default_locale, :in => I18n.available_locales

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  #attr_accessible :email, :password, :password_confirmation, :default_locale

  #### Associations ####
  has_and_belongs_to_many :roles
  #has_many :imports, :order => "created_at DESC"
  has_many :imports, -> { order('created_at DESC') }
  #has_many :taggings, :dependent => :destroy
  #has_many :tags, :through => :taggings
  #has_many :users, :through => :taggings
  #has_one :person
  has_one :bibapp_staff, -> { where enabled: true }
  has_many :authentications, :dependent => :destroy

  #before_create :make_activation_code
  before_validation :ensure_default_locale

  def is_libstaff?
    id.nil? ? false : BibappStaff.where(user_id: id, enabled: true).exists?
  end

  # BibappStaff Roles
  def has_explicit_role?(role_name, authorizable_obj = nil)
    if authorizable_obj.class == Class
      self.roles.named(role_name).where(:authorizable_type => authorizable_obj.to_s,
                                        :authorizable_id => nil).exists?
    else
      self.roles.named(role_name).where(:authorizable_type => authorizable_obj.class.to_s,
                                        :authorizable_id => authorizable_obj.id).exists?
    end
  end
  def has_role?(role, person)
  end
  
  # if using Role Inheritance as described at https://github.com/CanCanCommunity/cancancan/wiki/Role-Based-Authorization
  # but would only work with Abilities class set up as in documentation at link above
  def role?(base_role)
    #User::ROLES.index(base_role.to_sym) <= User::ROLES.index(role.to_sym)
    User::ROLES.index(base_role.to_sym) <= User::ROLES.index(self.bibapp_staff.role.to_sym)
  end
  
  def superadmin?
    return false unless is_libstaff?
    self.bibapp_staff.role == 'superadmin'
  end
  def admin?
    return false unless is_libstaff?
    self.bibapp_staff.role == 'admin'
  end
  def editor?
    return false unless is_libstaff?
    self.bibapp_staff.role == 'editor'
  end
  def author?
    return false unless is_libstaff?
    self.bibapp_staff.role == 'author'
  end
  def guest?
    return true if self.id.nil?
    self.bibapp_staff.role.nil? ? true : self.bibapp_staff.role == 'guest'  
  end

=begin
  # Activates the user in the database.
  def activate
    @activated = true
    self.activated_at = Time.now.utc
    self.activation_code = nil
    save_without_session_maintenance(:validate => false)
  end

  def active?
    # the existence of an activation code means they have not activated yet
    activation_code.nil?
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end
=end
  def email_update_code(new_email)
    Digest::SHA1.digest(self.salt + ':' + new_email)
  end

  def apply_omniauth(omniauth)
    self.email = omniauth['info']['email']
    #other stuff to make a legal user
    if self.new_record?
      self.password = self.password_confirmation = User.random_password
    end

    # Update user info fetching from omniauth provider
    case omniauth['provider']
      when 'open_id'
        #do any extra work needed for openid
    end
  end

  #this is for Authorization gem
  def uri
    Authorization::Base::PERMISSION_DENIED_REDIRECTION
  end


  def self.random_password(len = 20)
    chars = (("a".."z").to_a + ("1".."9").to_a)- %w(i o 0 1 l 0)
    Array.new(len, '').collect { chars[rand(chars.size)] }.join
  end

  protected

  def require_password?
    crypted_password.blank? || !password.blank?
  end

  def make_activation_code
    self.activation_code = Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by { rand }.join)
  end

  #make sure there is a default locale and that it is a symbol
  def ensure_default_locale
    self.default_locale ||= (I18n.locale || I18n.default_locale)
    self.default_locale = self.default_locale.to_sym
  end

    #overriding authorization gem for find syntax change
    def user_authorization_has_role(role_name, authorizable_obj = nil )
      if authorizable_obj.nil?
        case role_name
          when String then self.roles.detect { |role| role.name == role_name } ? true : false
          when Array then role_name.inject(false) { |memo,role| memo ? memo : has_role?(role) }
          else false
        end
      else
        role = authorization_get_role( role_name, authorizable_obj )
        role ? self.roles.exists?( role.id ) : false
      end
   end

  # return the first letter of each email, ordered alphabetically
  def self.letters
    self.select('DISTINCT SUBSTR(email, 1, 1) AS letter').order('letter').collect { |x| x.letter.upcase }.uniq
  end

end
