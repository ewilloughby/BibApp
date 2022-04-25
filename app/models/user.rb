require 'digest/sha1'
class User < ActiveRecord::Base

  acts_as_authentic do |c|
    #c.act_like_restful_authentication = true
    c.crypto_provider = ::Authlogic::CryptoProviders::SCrypt
  end
  
  #cancancan
  ROLES = %i[guest author editor admin superadmin]

  # Authorization plugin
 # acts_as_authorized_user
 # acts_as_authorizable

  validates_presence_of :email
  validates_presence_of :password, :if => :require_password?
  validates_presence_of :password_confirmation, :if => :require_password?
  validates_length_of :password, :within => 4..40, :if => :require_password?
  validates_confirmation_of :password, :if => :require_password?
  validates_length_of :email, :within => 3..100
  validates_uniqueness_of :email, :case_sensitive => false
  validates_inclusion_of :default_locale, :in => I18n.available_locales

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  #attr_accessible :email, :password, :password_confirmation, :default_locale

  #### Associations ####
  has_and_belongs_to_many :roles
  #has_many :imports, :order => "created_at DESC"
  has_many :imports, -> { order('created_at DESC') }
  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings
  has_many :users, :through => :taggings
  has_one :person
  has_many :authentications, :dependent => :destroy

  before_create :make_activation_code
  before_validation :ensure_default_locale

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

  # return the first letter of each email, ordered alphabetically
  def self.letters
    self.select('DISTINCT SUBSTR(email, 1, 1) AS letter').order('letter').collect { |x| x.letter.upcase }.uniq
  end

end
