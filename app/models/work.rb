require 'machine_name'
require 'stop_word_name_sorter'

class Work < ActiveRecord::Base
  include MachineName
  include StopWordNameSorter

  #acts_as_authorizable #some actions on Works require authorization

  cattr_accessor :current_user

  # Information about a 'pre-verified' Contributorship
  # for a specific Person in the system
  # (This occurs when adding a Work directly to a Person).
  attr_accessor :preverified_person
  # For an import we need this flag in order to be able to create the contributorships at the right time
  attr_accessor :skip_create_contributorships

  serialize :scoring_hash

  #### Associations ####
  belongs_to :publication
  belongs_to :publisher

  #has_many :name_strings, :through => :work_name_strings, :order => "position"

  #has_many :work_name_strings, :order => "position", :dependent => :destroy

# Replaced above syntax for :order with below, reversed order 
  has_many :work_name_strings, -> { order("position ASC") }, dependent: :destroy
  has_many :name_strings, -> { order("position ASC") }, through: :work_name_strings


 # has_many :people, :through => :contributorships,
 #          :conditions => ["contributorship_state_id = ?", Contributorship::STATE_VERIFIED]
 has_many :contributorships, dependent: :destroy
 has_many :people, -> { where("contributorship_state_id = ?", Contributorship::STATE_VERIFIED) }, through: :contributorships

  has_many :keywordings, dependent: :destroy
  has_many :keywords, through: :keywordings

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings
  has_many :users, :through => :taggings

  has_many :external_system_uris

  has_many :attachments, :as => :asset
  #belongs_to :work_archive_state

  validates_presence_of :title_primary
  validates_numericality_of :publication_date_year, :allow_nil => true, :greater_than => 0
  validates_inclusion_of :publication_date_month, :in => 1..12, :allow_nil => true
  validates_each :publication_date_month do |record, attr, value|
    if value.present?
      unless record.publication_date_year
        record.errors.add attr, 'must have a year in order to supply a month'
      end
    end
  end
  validates_inclusion_of :publication_date_day, :in => 1..31, :allow_nil => true
  validates_each :publication_date_day do |record, attr, value|
    if value.present?
      if  record.publication_date_year and record.publication_date_month
        begin
          Date.new(record.publication_date_year, record.publication_date_month, record.publication_date_day)
        rescue
          record.errors.add attr, 'is not a valid day in the given year and month'
        end
      else
        record.errors.add attr, 'must have a year and a month to supply a day'
      end
    end
  end
  #### Named Scopes ####
  #Various Work Statuses
  STATE_IN_PROCESS = 1
  STATE_DUPLICATE = 2
  STATE_ACCEPTED = 3
  scope :in_process, -> { where(work_state_id: STATE_IN_PROCESS) }
  scope :duplicate, -> { where(work_state_id: STATE_DUPLICATE) }
  scope :accepted, -> { where(work_state_id: STATE_ACCEPTED) }

  ARCHIVE_STATE_INITIAL = 1
  ARCHIVE_STATE_READY_TO_ARCHIVE = 2
  ARCHIVE_STATE_ARCHIVED = 3
  #Various Work Archival Statuses
  scope :ready_to_archive, -> { where(work_archive_state_id: ARCHIVE_STATE_READY_TO_ARCHIVE) }
  scope :archived, -> { where(work_archive_state_id: ARCHIVE_STATE_ARCHIVED) }

  TO_BE_BATCH_INDEXED = 1
  NOT_TO_BE_BATCH_INDEXED = 0

  scope :to_batch_index, -> { where(batch_index: TO_BE_BATCH_INDEXED) }

  #Various Work Contribution Statuses
  scope :unverified, -> { where('contributorships.contributorship_state_id = ?', Contributorship::STATE_UNVERIFIED) }
  scope :verified,   -> { where('contributorships.contributorship_state_id = ?', Contributorship::STATE_VERIFIED) }
  scope :denied,     -> { where('contributorships.contributorship_state_id = ?', Contributorship::STATE_DENIED) }
  scope :visible,    -> { where('contributorships.hide = ?', false) }

  scope :for_authority_publication,
        lambda { |authority_publication_id| where(:authority_publication_id => authority_publication_id) }

  scope :most_recent_first, -> { order('updated_at DESC') }
  scope :by_publication_date, -> { order('publication_date_year DESC, publication_date_month DESC, publication_date_day DESC') }

  def self.orphans
    (self.orphans_no_contributorships + self.orphans_denied_contributorships).uniq.sort { |a, b| a.title_primary <=> b.title_primary }
  end

  def self.orphans_no_contributorships
    self.order('title_primary').joins('LEFT JOIN contributorships ON works.id = contributorships.work_id').
        where(:contributorships => {:id => nil})
  end

  #The implementation may be improvable, but this only does 3 SQL calls. It could be done in one, but I'm not
  #sure how to accomplish that in the Rails query language.
  #We first find all works that have at least one denied contributorship. Then we load those works eager loading
  #all their contributorships and find the ones with all denied contributorships in code
  def self.orphans_denied_contributorships
    contributorships = Contributorship.denied.select("DISTINCT work_id")
    works = self.includes(:contributorships).where(:id => contributorships.collect { |c| c.work_id })
    works.select do |work|
      !work.contributorships.detect { |c| !c.denied? }
    end
  end

  #### Callbacks ####
  before_validation :set_initial_states, :on => :create
  after_create :after_create_actions
  before_save :before_save_actions
  after_save :after_save_actions

  # After Create only
  # (Note: after create callbacks *must* be placed in Work model,
  #  for faux-accessors to work properly)
  def after_create_actions
    create_work_name_strings
    create_keywords
    create_tags
  end

  def after_save_actions
    deduplicate
    create_contributorships unless self.skip_create_contributorships
  end

  def before_save_actions
    update_authorities
    update_scoring_hash
    update_archive_state
    update_machine_name
    update_sort_name
  end

  #### Serialization ####
  serialize :serialized_data

  ##### Work State Methods #####
  def in_process?
    self.work_state_id == STATE_IN_PROCESS
  end

  def is_in_process
    self.work_state_id = STATE_IN_PROCESS
  end

  def duplicate?
    self.work_state_id == STATE_DUPLICATE
  end

  def is_duplicate
    self.work_state_id = STATE_DUPLICATE
  end

  def accepted?
    self.work_state_id == STATE_ACCEPTED
  end

  def is_accepted
    self.work_state_id = STATE_ACCEPTED
  end

  # The field for work status in BibApp's Solr Index
  def self.solr_status_field
    return "status:"
  end

  # The Solr filter for accepted works...this is used by default, as
  # we don't want incomplete works to normally appear in BibApp
  def self.solr_accepted_filter
    return solr_status_field + STATE_ACCEPTED.to_s
  end

  # The Solr filter for duplicate works...these works are normally
  # hidden by BibApp, except to administrators
  def self.solr_duplicate_filter
    return solr_status_field + STATE_DUPLICATE.to_s
  end


  ##### Work Archival State Methods #####
  # setting following to true and false will show the "Archive Research" link with the ability
  # on production to create an attachment of the uploaded file to the work
  def ready_to_archive?
    false
  end
  def archived?
    true
  end
=begin
  def init_archive_status
    self.work_archive_state_id = ARCHIVE_STATE_INITIAL
  end

  def has_init_archive_status?
    self.work_archive_state_id == ARCHIVE_STATE_INITIAL
  end

  def ready_to_archive?
    self.work_archive_state_id == ARCHIVE_STATE_READY_TO_ARCHIVE
  end

  def is_ready_to_archive
    self.work_archive_state_id = ARCHIVE_STATE_READY_TO_ARCHIVE
  end

  def archived?
    return true if self.work_archive_state_id == ARCHIVE_STATE_ARCHIVED
  end

  def is_archived
    self.work_archive_state_id = ARCHIVE_STATE_ARCHIVED
  end
=end

  #batch indexing related
  def mark_indexed
    self.batch_index = NOT_TO_BE_BATCH_INDEXED
    self.save
  end

  ########## Methods ##########
  # Rule #1: Comment H-E-A-V-I-L-Y
  # Rule #2: Include @TODOs

  # List of all currently enabled Work Types
  def self.types
    # @TODO: Add each work subklass to this array
    # "Journal Article",
    # "Conference Proceeding",
    # "Book"
    # more...
    ["Artwork",
     "Book (Section)",
     "Book (Whole)",
     "Book Review",
     "Composition",
     "Conference Paper",
     "Conference Poster",
     "Conference Proceeding (Whole)",
     "Dissertation / Thesis",
     "Exhibition",
     "Grant",
     "Journal (Whole)",
     "Journal Article",
     "Monograph",
     "Patent",
     "Performance",
     "Presentation / Lecture",
     "Recording (Moving Image)",
     "Recording (Sound)",
     "Report",
     "Web Page",
     "Generic"]
  end

  def self.type_to_class(type)
    t = type.gsub(" ", "") #remove spaces
    t.gsub!("/", "") #remove slashes
    t.gsub!(/[()]/, "") #remove any parens
    t.constantize #change into a class
  end

  # Creates a new work from an attribute hash
  # Caller must check to see if there were any validation errors
  def self.create_from_hash(h, add_contributorships = true)
    klass = h[:klass]

    # Are we working with a legit SubKlass?
    klass = klass.constantize
    if klass.superclass != Work
      raise NameError.new("#{klass_type} is not a subclass of Work")
    end

    work = klass.new
    work.title_primary = h[:title_primary]
    work.skip_create_contributorships = !add_contributorships
    work.update_from_hash(h)
  end

  def denormalize_role(role)
    case role
      when 'Author'
        self.creator_role
      when 'Editor'
        self.contributor_role
      else
        role
    end
  end

  def delete_non_work_data(h)
    [:klass, :work_name_strings, :publisher, :publication, :issn_isbn, :keywords, :source, :external_id].each do |key|
      h.delete(key)
    end
    h
  end

  def publication_name_from_hash(h)
    case self.class.to_s
      when 'BookWhole', 'Monograph', 'JournalWhole', 'ConferenceProceedingWhole', 'WebPage'
        h[:title_primary] ? h[:title_primary] : 'Unknown'
      when 'BookSection', 'ConferencePaper', 'ConferencePoster', 'PresentationLecture', 'Report'
        h[:title_secondary] ? h[:title_secondary] : 'Unknown'
      when 'JournalArticle', 'BookReview', 'Performance', 'RecordingSound', 'RecordingMovingImage', 'Generic'
        h[:publication] ? h[:publication] : 'Unknown'
      else
        nil
    end
  end

  # Updates an existing work from an attribute hash
  # Caller must check to see if there were any validation errors.
  def update_from_hash(h)
    work_name_strings = (h[:work_name_strings] || []).collect do |wns|
      {:name => wns[:name], :role => self.denormalize_role(wns[:role])}
    end
    self.set_work_name_strings(work_name_strings)

    #If we are adding to a person, pre-verify that person's contributorship
    person = Person.find(h[:person_id]) if h[:person_id]
    self.preverified_person = person if person

    ###
    # Setting Publication Info, including Publisher
    ###
    publication_name = publication_name_from_hash(h)

    issn_isbn = h[:issn_isbn]
    if publication_name == 'Unknown' and issn_isbn.present?
      publication_name = "Unknown (#{issn_isbn})"
    end

    self.set_publication_info(:name => publication_name,
                              :issn_isbn => issn_isbn,
                              :publisher_name => h[:publisher])

    ###
    # Setting Keywords
    ###
    self.set_keyword_strings(h[:keywords])

    # Clean the hash of non-Work table data
    # Cleaning will prepare the hash for ActiveRecord insert
    self.delete_non_work_data(h)

    # When adding a work to a person, person_id causes work.save to fail
    h.delete(:person_id) if h[:person_id]

    #save remaining hash attributes
    saved = self.update_attributes(h)

    return self

  end


  # Deduplication: deduplicate Work records on save
  def deduplicate
    logger.debug("\n\n===DEDUPLICATE===\n\n")

    #Find all possible dupe candidates from Solr
    dupe_candidates = Index.possible_accepted_duplicate_works(self)
    logger.debug("\nDuplicates: #{dupe_candidates.size}")

    #Check if any duplicates found.
    #@TODO: Be smarter about this...first in probably shouldn't always win
    #IMPORTANT: we update fields directly here because this is in an after save callback and
    #we don't want to trigger another save when we make a change here!
    #Eventually (by Rails 3.2) we can just use update_column. For 3.0 we need to do something like this.
    #Note that we also set the value in self as later callbacks may want the value set here.
    if dupe_candidates.empty?
      self.class.where(:id => self.id).update_all(:work_state_id => STATE_ACCEPTED)
      self.is_accepted
      #Only mark as duplicate if this work wasn't previously accepted
    elsif !self.accepted?
      self.class.where(:id => self.id).update_all(:work_state_id => STATE_DUPLICATE)
      self.is_duplicate
    end

    #@TODO: Is there a way that we can calculate the *canonical best*
    # version of a work? We've tried this in the past, but we need to do
    # it in a better way (e.g.  we don't end up accidentally re-marking things as
    # dupes that have previously been determined to not be dupes by a human)
  end

  def set_for_index_and_save
    self.batch_index = TO_BE_BATCH_INDEXED
    self.save
  end

  # Finds year of publication for this work
  def year
    publication_date_year
  end

  # Initializes an array of Keywords
  # and saves them to the current Work
  # Arguments:
  #  * array of keyword strings
  def set_keyword_strings(keyword_strings)
    keyword_strings = Array.wrap(keyword_strings)
    keywords = keyword_strings.uniq.collect do |add|
      Keyword.find_or_initialize_by_name(add)
    end
    self.set_keywords(keywords)
    self.save
  end

  # Initializes an array of Tags
  # and saves them to the current Work
  # Arguments:
  #  * array of tag strings
  def set_tag_strings(tag_strings)
    tag_strings ||= []
    tags = tag_strings.to_a.uniq.collect do |add|
      Tag.find_or_initialize_by_name(add)
    end
    self.set_tags(tags)
    self.save
  end

  # Updates keywords for the current Work
  # If this Work is still a *new* record (i.e. it hasn't been created
  # in the database), then the keywords are just cached until the
  # Work is created.
  # Based on ideas at:
  #   http://blog.hasmanythrough.com/2007/1/22/using-faux-accessors-to-initialize-values
  #
  # Arguments:
  #  * array of Keywords
  def set_keywords(keywords)
    if self.new_record?
      @keywords_cache = keywords
    else
      self.update_keywordings(keywords)
    end
  end

  # Updates tags for the current Work
  # If this Work is still a *new* record (i.e. it hasn't been created
  # in the database), then the tags are just cached until the
  # Work is created.
  # Based on ideas at:
  #   http://blog.hasmanythrough.com/2007/1/22/using-faux-accessors-to-initialize-values
  #
  # Arguments:
  #  * array of Tags
  def set_tags(tags)
    if self.new_record?
      @tags_cache = tags
    else
      self.update_taggings(tags)
    end
  end

  # Updates Work name strings
  # (from a hash of "name" and "role" values)
  # and saves them to the current Work
  # Arguments:
  #  * hash {:name => "Donohue, T.", :role => "Author | Editor" }
  # this is called from line 452 self.set_work_name_strings(work_name_strings)
  def set_work_name_strings(work_name_string_hash)
    if self.new_record?
      @work_name_strings_cache = work_name_string_hash
    else
      # Discovered bug, if a name_string is edited then contributorship association is lost
      # this is the only call into this method so need to update contributorship
      #self.update_work_name_strings(work_name_string_hash)
      
      self.update_from_existing_work_name_strings(work_name_string_hash, self.work_name_strings)
      
    end
  end

  def set_publisher_from_name(publisher_name = nil)
    publisher_name = "Unknown" if publisher_name.blank?
    # changed; could be self or perform a re-link to record with same authority_id
    set_publisher = Publisher.find_or_create_by(name: publisher_name, romeo_color: 'unknown')
    if Publisher.where(name: set_publisher.name, id: set_publisher.authority_id, romeo_color: set_publisher.romeo_color).exists?
      set_publisher = Publisher.where(name: set_publisher.name, id: set_publisher.authority_id, romeo_color: set_publisher.romeo_color).first
    end
    self.set_initial_publisher(set_publisher)

    unless self.new_record?
      unless self.publisher == set_publisher
        set_publisher.authority_id = set_publisher.id if set_publisher.authority_id.blank?
        self.publisher_id = set_publisher.authority_id
        self.update_column(:publisher_id, set_publisher.authority_id) 
      end
    end
    
    return set_publisher
  end

  def set_publication_from_name(name, issn_isbn, set_publisher)
    return unless name
    
    # worst kind of if then 
    if issn_isbn.present?

      publication = Publication.find_or_create_by(name: name, issn_isbn: issn_isbn.to_s, initial_publisher_id: set_publisher.id)

    elsif set_publisher
      
      if set_publisher.name == 'Unknown'
        #try to look up a publisher from the publication name - if that doesn't work go ahead
        #and use the set_publisher
        publication = Publication.find_or_create_by(name: name)
        # CHECK THIS, IS publisher in scope ??, original didnt compare, 
        # it assigned (if publisher = publication.publisher)
        if publisher == publication.publisher 
          self.set_initial_publisher(publisher)
        else
          publication.publisher = set_publisher
        end
      else
        publication = Publication.find_or_create_by(name: name, initial_publisher_id: set_publisher.id)
      end
    else
      publication = Publication.find_or_create_by(name: name)
    end
    
    unless publication.authority_id.blank?
      unless Publication.exists?(publication.authority_id)
        publication.authority_id = publication.id
      end
    else
      publication.authority_id = set_publisher.authority_id
    end
    
    publication.save! if publication.has_changes_to_save?
    set_initial_publication(publication) # really; change initial_publication ?? Why and does setting do anything?
  end


  # Initializes the Publication information
  # and saves it to the current Work
  # Arguments:
  #  * hash {:name => "Publication name",
  #          :issn_isbn => "Publication ISSN or ISBN",
  #          :publisher_name => "Publisher name" }
  #  (not all hash values need be set)
  def set_publication_info(publication_hash)
    logger.debug("\n\n===SET PUBLICATION INFO===\n\n")

    # If there is no publisher name, set to Unknown
    set_publisher = set_publisher_from_name(publication_hash[:publisher_name])
    set_publication_from_name(publication_hash[:name], publication_hash[:issn_isbn], set_publisher)
    self.save!
  end

  # All Works begin unverified
  def set_initial_states
    self.is_in_process
    #self.init_archive_status
  end

  #Build a unique ID for this Work in Solr
  def solr_id
    "Work-#{id}"
  end

  # Generate a key based on title information
  # which can be used to determine if a Work is a duplicate
  def title_dupe_key
    pub_authority = ""
    unless self.publication.nil? or self.publication.authority.nil?
      pub_authority = self.publication.authority.machine_name.to_s.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8)
    end
    
    # not sure if this a problem any longer EM March 28,2014
    volume = get_attribute_dupe_info('volume')
    
    start_page = get_start_page(self.start_page)
    #vol_stpage = self.volume.nil? ? "||#{start_page}" : "#{self.volume.to_s}||#{start_page}"
    vol_stpage = "#{volume}||#{start_page}"
    
    #if self.publication and self.publication.authority
    #  self.machine_name.to_s + "||" + self.year.to_s + "||" + self.publication.authority.machine_name.to_s + "||" + vol_stpage
    #end
    
    year = get_attribute_dupe_info('year')
    
    logger.debug("\n\n =========== TITLE_DUPE_KEY ======\n")
    logger.debug(self.machine_name.to_s + "||" + year + "||" + pub_authority + "||" + vol_stpage)
    
    #self.machine_name.to_s + "||" + self.year.to_s + "||" + pub_authority + "||" + vol_stpage
    self.machine_name.to_s + "||" + year + "||" + pub_authority + "||" + vol_stpage
  end

  # Generate a key based on Author/Editor information
  # which can be used to determine if a Work is a duplicate
  def name_string_dupe_key
    # NameString Dupe Key Format:
    # [First NameString.machine_name]||[Work.year]||[Work.type]||[Work.machine_name]
    if self.name_strings.present?
      start_page = get_start_page(self.start_page)
      #vol_stpage = self.volume.nil? ? "||#{start_page}" : "#{self.volume.to_s}||#{start_page}"
      volume = get_attribute_dupe_info('volume')
      vol_stpage = "#{volume}||#{start_page}"
      
      year = get_attribute_dupe_info('year')
      
      nstring = self.name_strings[0].machine_name.to_s.split(/\s/)
      fauthor = nstring[0]
      nstring[1..nstring.length].each { |n| fauthor << " ".concat(n[0,1]) }
      
      logger.debug("\n\n ========= NAME_STRING_DUPE_KEY ============= \n")
      logger.debug(fauthor + "||" + year + "||" + self.type.to_s + "||" + self.machine_name.to_s + "||" + vol_stpage)
      
      fauthor + "||" + year + "||" + self.type.to_s + "||" + self.machine_name.to_s + "||" + vol_stpage
      # if do not want type
      #fauthor + "||" + year + "||" + self.machine_name.to_s + "||" + vol_stpage
    end
  end

  # If the Work is accepted ensures Contributorships are set for each WorkNameString claim
  # associated with the Work.
  def create_contributorships
    
    logger.info "\n\n===== CREATE_CONTRIBUTORSHIPS =====\n\n"
    logger.info "WORKING ON #{self.title_primary}"
    
    logger.debug "WorkNameString count: #{self.work_name_strings.size}"
    logger.info "Is Accepted: #{self.accepted?}"
    logger.info("Include original_data: #{self.saved_change_to_attribute?(:original_data)}") 
    
    # original_data check ensure contribs for manually added works are created
    if self.accepted? || self.saved_change_to_attribute?(:original_data).present? == false
      self.work_name_strings.each do |cns|
        # msk since with addition of update_from_existing_work_name_strings method
        # otherwise would re-create the contributor
        next if cns.destroyed? 
        
        # Find all People with a matching PenName claim
        claims = PenName.for_name_string(cns.name_string_id)
        
        claims.each do |claim|          
          next if claim.person.nil? # MSK in case a person is deleted, which may exist if index out-of-sync
          logger.debug("\n\n ===== FIND-OR-CREATE for: #{claim.inspect} =========\n\n")
          
          # find or create a Contributorship for each claim
          Contributorship.find_or_create_by(work_id: self.id, person_id: claim.person.id, pen_name_id: claim.id, role: cns.role)
        end
      end
    else
      logger.info "\n\n===== NOTHING TO DO - CREATE CONTRIBUTORSHIPS =====\n\n"
    end
  end

  # Return a hash comprising all the Contributorship scoring methods
  def update_scoring_hash
    self.scoring_hash = {:year => self.publication_date_year,
                         :publication_id => self.publication_id,
                         :collaborator_ids => self.name_strings.collect { |ns| ns.id }, #there's an error if one tries to do this the natural way
                         :keyword_ids => self.keyword_ids}
  end

  def update_archive_state
    if self.archived_at
      self.is_archived
    elsif self.attachments.present?
      self.is_ready_to_archive
    elsif self.ready_to_archive?
      #if marked ready, but no attachments then revert to initial status
      self.init_archive_status
    end
  end

  #base machine name of work on title_primary
  def update_machine_name(force = true)
    if self.title_primary_changed? or self.machine_name.blank? or force
      self.machine_name = make_machine_name(self.title_primary)
    end
  end

  def update_authorities
    if self.publication
      # self.publication could be nil
      logger.debug("\n\n ================== IN WORK_UPDATE_AUTHORITIES on ID: #{self.id} ==============\n")
      logger.debug("self.publication.authority_id: #{self.publication.authority_id} ==============\n")
      logger.debug("self.publication.authority.publisher_id: #{self.publication.authority.publisher_id} ==============\n")
      self.publication_id = self.publication.authority_id
      self.publisher_id = self.publication.authority.publisher_id
    end
  end

  # Returns to Work Type URI based on the EPrints Application Profile's
  # Type vocabulary.  If the type is not available in the EPrints App Profile,
  # then the URI of the appropriate DCMI Type is returned.
  #
  # This is used for generating a SWORD package
  # which contains a METS file conforming to the EPrints DC XML Schema.
  #
  # For more info on EPrints App. Profile, and it's Type vocabulary, see:
  # http://www.ukoln.ac.uk/repositories/digirep/index/EPrints_Application_Profile
  #
  #Maps our Work Types to EPrints Application Profile Type URIs,
  # or to the DCMI Type Vocabulary URI (if not in EPrints App. Profile
  # Override in a subclass to assign a specific type_uri to that subclass
  # By default return nil
  #To get the full map used before breaking out into subclasses, which includes some types for
  #which there may not yet be subclasses, consult this method in version control history prior to 2011-02-28
  def type_uri
    return nil
  end

  # TODO As far as I can tell, to_s is only used in name and to_apa is only used in to_s
  # to_apa claims in a comment to have a real use, but I haven't checked it. So these methods
  # may be removable
  def name
    return self.to_s
  end

  #Convert Work into a String
  def to_s
    # Default to displaying Work in APA citation format
    to_apa
  end

  #Convert Work into a String in the APA Citation Format
  # This is currently used during generation of METS file
  # conforming to EPrints DC XML Schema for use with SWORD.
  # @TODO: There is likely a better way to do this more generically.
  # TODO: it may also not be doing what it should - what if there are both authors and editors
  # - it's not clear how they are distinguished.
  # TODO: in an ideal world this is just WorkExport.new.drive_csl('apa', self).html_safe
  # However, I'm not sure that the current csl and/or citeproc.rb does it well enough to be better
  # It may also be that how WorkExport feeds the work into the processor is a problem.
  # Note for future reference there is a ruby 1.9.2 citeproc-ruby that is actually active - look into it
  # when appropriate!
  # Note that we could, if necessary, deploy this as a service
  def to_apa
    String.new.tap do |citation_string|
      #---------------------------------------------
      # All APA Citation formats start out the same:
      #---------------------------------------------
      #Add authors
      append_apa_author_text(citation_string)

      #Add editors
      append_apa_editor_text(citation_string)

      #Publication year
      citation_string << " (#{self.publication_date_year})" if self.publication_date_year

      #Only add a period if the string doesn't currently end in a period.
      citation_string << ". " if !citation_string.match("\.\s*\Z")

      #Title
      citation_string << "#{self.title_primary}. " if self.title_primary

      #Now add in anything specific to the type of work, using a generic one defined in this model if
      #thee work type does not override.
      append_apa_work_type_specific_text!(citation_string)
    end
  end

  def append_apa_author_text(citation_string)
    append_apa_contributors_text(citation_string, self.work_name_strings.author.includes(:name_string))
  end

  def append_apa_editor_text(citation_string)
    append_apa_contributors_text(citation_string, self.work_name_strings.editor.includes(:name_string))
    citation_string << " (Ed.)." if self.work_name_strings.editor.count == 1
    citation_string << " (Eds.)." if self.work_name_strings.editor.count > 1
  end

  def append_apa_contributors_text(citation_string, collection)
    collection.first(5).each do |wns|
      name = wns.name_string.name
      name = ", #{name}" unless citation_string.blank?
      citation_string << name
    end
  end

  #defines a default behavior - override in subclass to specialize
  def append_apa_work_type_specific_text!(citation_string)
    citation_string << "#{self.publication.authority.name}, " if self.publication
    citation_string << self.volume if self.volume
    citation_string << "(#{self.issue})" if self.issue
    citation_string << ", " if self.start_page or self.end_page
    citation_string << self.start_page if self.start_page
    citation_string << "-#{self.end_page}" if self.end_page
    citation_string << "."
  end

  #Get all Author names on a Work, return as an array of hashes
  def authors
    self.work_name_strings.with_role(self.creator_role).includes(:name_string).collect do |wns|
      ns = wns.name_string
      {:name => ns.name, :id => ns.id}
    end
  end

  #Get all Editor Strings of a Work, return as an array of hashes
  def editors
    return [] if self.contributor_role == self.creator_role
    self.work_name_strings.with_role(self.contributor_role).includes(:name_string).collect do |wns|
      ns = wns.name_string
      {:name => ns.name, :id => ns.id}
    end
  end

  def self.creator_role
    raise RuntimeError, 'Subclass responsibility'
  end

  def self.contributor_role
    raise RuntimeError, 'Subclass responsibility'
  end

  def creator_role
    self.class.creator_role
  end

  def contributor_role
    self.class.contributor_role
  end

  def all_contributor_roles
    self.class.roles - [self.creator_role]
  end

  # In case there isn't a subklass open_url_kevs method
  def open_url_kevs
    open_url_kevs = Hash.new
    open_url_kevs[:format] = "&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal"
    open_url_kevs[:genre] = "&rft.genre=article"
    open_url_kevs[:title] = "&rft.atitle=#{CGI.escape(self.title_primary)}"
    unless self.publication.nil?
      open_url_kevs[:source] = "&rft.jtitle=#{CGI.escape(self.publication.authority.name)}"
      open_url_kevs[:issn] = "&rft.issn=#{self.publication.issns.first[:name]}" if !self.publication.issns.empty?
    end
    open_url_kevs[:date] = "&rft.date=#{self.publication_date_string}"
    open_url_kevs[:volume] = "&rft.volume=#{self.volume}"
    open_url_kevs[:issue] = "&rft.issue=#{self.issue}"
    open_url_kevs[:start_page] = "&rft.spage=#{self.start_page}"
    open_url_kevs[:end_page] = "&rft.epage=#{self.end_page}"

    return open_url_kevs
  end

  #return OpenURL context string for this hash, e.g. for mets export of work
  #ignore any key that has a nil value
  def open_url_context_string
    self.open_url_context_hash.collect do |k, v|
      v ? URI.escape("&#{k}=#{v}") : nil
    end.compact.join('')
  end

  #return components to be incorporated into open_url_context_string
  #override in subclasses to add additional elements or change what happens
  #here
  def open_url_context_hash
    self.open_url_base_context_hash
  end

  def open_url_base_context_hash
    {'ctx_ver' => 'Z39.88-2004'}
  end

  def update_type_and_save(new_type)
    self[:type] = new_type
    self.save
  end

  def update_solr
    Index.update_solr(self)
  end

  def update_solr_no_autocommit
    Index.update_solr(self, false)
  end

  #The following methods are used by the IndexObserver, distinct from the other reindexing that happens.
  def require_reindex?
    !self.batch_index? and self.changed?
  end

  def reindex_after_save
    Index.update_solr(self)
  end

  def reindex_before_destroy
    logger.debug("\n\n ==== CALLING WORKS.reindex_before_destroy TO_DELETE_SOLR_RECORD ++ work id #{self.id}  ====\n\n")
    Index.remove_from_solr(self)
  end

  def publication_date_string
    if self.publication_date_day
      sprintf('%04d-%02d-%02d', self.publication_date_year, self.publication_date_month, self.publication_date_day)
    elsif self.publication_date_month
      sprintf('%04d-%02d', self.publication_date_year, self.publication_date_month)
    elsif self.publication_date_year
      sprintf('%04d', self.publication_date_year)
    else
      ""
    end
  end

  protected

  # Update Keywordings - updates list of keywords for Work
  # Arguments:
  #   - Work object
  #   - collection of Keyword objects
  def update_keywordings(keywords)
    self.keywords = keywords || []
  end

  def update_taggings(tags)
    self.tags = tags || []
  end

  # Create keywords, after a Work is created successfully
  #  Called by 'after_create' callback
  def create_keywords
    #Create any initialized keywords and save to Work
    self.set_keywords(@keywords_cache) if @keywords_cache
  end


  def create_tags
    #Create any initialized tags and save to Work
    self.set_tags(@tags_cache) if @tags_cache
  end

  # Updates WorkNameStrings
  # (from a hash of "name" and "role" values)
  # and saves them to the given Work object
  # Arguments:
  #  * Work object
  #  * Array of hashes {:name => "Donohue, Tim", :role=> "Author | Editor" }
  def update_from_existing_work_name_strings(new_name_strings_hash, original_work_name_strings)
    logger.debug("\n\n============ ENTERING_METHOD::update_from_existing_work_name_strings ============\n\n")
    
    return unless new_name_strings_hash
    
    # this is work_name_strings.id and name_string.name mashup
    # adding encoding call to ensure matches
    #names_arr = original_work_name_strings.collect{|t| [NameString.find(t.name_string_id).name, t.id, 'P']}
    names_arr = original_work_name_strings.collect{|t| 
      [NameString.find(t.name_string_id).name.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8), t.id, 'P']
    }
    
    new_name_strings_hash.each_with_index do |h,pos|
      name = h[:name]
      0.upto(names_arr.length-1) {|loc| 
        if (names_arr[loc][0] <=> name) == 0 && names_arr[loc][2] == 'P'
         new_name_strings_hash[pos][:wns_id] = names_arr[loc][1]
         # in case of duplicate names, need to remove from potential list
         # not sure about ordering differences between passed in and original and if it will cause a problem
         names_arr[loc][2] = 'F'  
         break
        end
      }
    end
    
    logger.debug("\n\n========ORIGINAL_WORK_NAME_STRINGS ===============\n")
    logger.debug(original_work_name_strings.inspect)
    
    logger.debug("\n\n=========NAME_STRING_ARR ==================\n")
    logger.debug(names_arr.inspect)
    
    logger.debug("\n\n=======NEW_NAME_STRINGS_HASH_WITH_ADDED_WNS_ID ================\n")
    logger.debug(new_name_strings_hash.inspect)
    
    names_to_skip = Array.new
    
    # changing to <= for check in cases where changing only an existing name
    # from one that was a contrib to one that is not, Michelle found bug NOV 16 2015
    #if new_name_strings_hash.length <= original_work_name_strings.length
      
    logger.debug("\n\n =========INITIAL-CHECK-ON-CONTRIBUTORSHIP CHANGE =========== \n")
    
    narr = new_name_strings_hash.collect{|x| x[:wns_id]}
    oarr = original_work_name_strings.collect{|x| x.id}
    
    logger.debug("new names: #{narr.inspect}")
    logger.debug("original: #{oarr.inspect}")
    
    names_to_skip = pen_names_submit_diff(narr, oarr).collect{|x| x }.compact
    
    logger.debug("\n\n ========== SOME-NAMES-EXIST-TO-DELETE ============\n")
    logger.debug("#{names_to_skip.inspect}")
    
    names_to_skip.each do |wid|
      logger.debug("FINDING_WNS_WITH_ID: #{wid}")
      
      twns = WorkNameString.find(wid)
      
      pids = PenName.where(:name_string_id => twns.name_string_id) # may be more than one
      pids.each do |pid|
        cx = Contributorship.find_by_work_id_and_pen_name_id_and_role(twns.work_id, pid.id, twns.role)
        if cx
          logger.debug("\n\n === DELETING_CONTRIBUTOR: #{cx.inspect}")
          Contributorship.delete(cx.id)
        end
      end
      
      # and remove work_name_string
      self.work_name_strings.each do |sw| 
        if sw.id == twns.id
          logger.debug("DELETING WNS: #{twns.inspect}")
          sw.delete 
        end
      end
      
      # revise original hash to reflect deletions
      # as this is ActiveRecord:Relation no longer supports delete_if, turn into an array 
      # original_work_name_strings.delete_if{|owns| owns.id == twns.id}
      original_work_name_strings.to_a.delete_if{|owns| owns.id == twns.id}
    end
        
    existing_wns = original_work_name_strings.dup # don't think we really need the dup
    counter = 0
    new_name_strings_hash.flatten.each_with_index do |ns_hash, position|
      
      break if existing_wns[position].nil?
      
      # increment, is there a better way since only used to see about any remaining
      counter += 1
       
      # need name from existing work_name_strings
      wns = existing_wns[position]
      wns_name = wns.name_string.name
      
      # are they the same person or have the same role, if not
      unless ns_hash[:name] == wns_name && ns_hash[:role] == wns[:role]

        machine_name = make_machine_name(ns_hash[:name])
        name = ns_hash[:name].strip
        
        ## if not using varbinary in name field need to do the following
        # using binary on column may cause problems with index
        #if NameString.where(machine_name: machine_name, name: name).exists?
        #  exists= NameString.where(machine_name: machine_name, name: name).first
        #  unless (exists.name <=> name) == 0
        #    exists.name = name
        #    exists.save
        #  end
        #end
        
        ns = NameString.find_or_create_by(machine_name: machine_name, name: name)
        
        # ABOVE HAS POTENTIAL hyphen issue as of June 20, 2014 -- see file aa_hyphenated ......
        # MAY NEED TO DO THE FOLLOWING, BUT WOULD NEED TO remove the unique index just on machine_name
        # AND make the unique index a combination of both fields
        # ns = NameString.where(machine_name: machine_name, name: name).first_or_create

        # already know that this name is not in current work_name_string record
        # so find original wns record to update
        
        arr = [wns.work_id, wns.name_string_id, wns.role, wns.position]
        origwns = WorkNameString.find_by_work_id_and_name_string_id_and_role_and_position(*arr)
        logger.debug("\n\n====== FOUND_ORIG WNS =============\n")
        logger.debug(origwns.inspect)
        
        origwns.name_string_id = ns.id # assigning changed name
        
        # bypass validation and callback checks, which might otherwise occur
        # if editing a PenName to a wns with same penname
        # laurie c from laurie c a (when a lauri c already exists)
        
        origwns.update_column(:role, ns_hash[:role]) if ns_hash[:role] != wns[:role]
        origwns.update_column(:name_string_id, ns.id) 
        logger.debug("\n\n SAVED new name_string_id: #{ns.id} for work_name_string with id: #{origwns.id}\n")

        # do I add the work_name_strings.id to the hash for ordering if sequence of names has changed?
        new_name_strings_hash[position][:wns_id] = origwns.id
        
        # also need to update contributorships, if exist in original record
        # and if this is the same person, need to believe this new name_string is being associated as well
        contribs = self.contributorships.select {|cc| cc.pen_name.name_string_id == wns.name_string_id && cc.work_id == self.id}
        if contribs.blank? == false
          logger.debug("\n\n ========== FOUND #{contribs.length} FOR THIS WORK ===========\n")
          
          contribs.each do |cc| 
            logger.debug(" CONTRIBUTORSHIP-WORK, finding PenName match on this name_string \n")
            logger.debug(cc.inspect)
            
            # BUT SHOULD I ALSO DELETE THE original contrib for this person and this work????
            if PenName.where(name_string_id: ns.id, person_id: cc.person_id).exists?
              logger.debug("\n\n ====NAME-STRING-FOR-PERSON exists: #{cc.person_id} with name_string_id: #{ns.id} ===\n")
              #npn = PenName.find_or_create_by_name_string_id_and_person_id(ns.id, cc.person_id)
              npn = PenName.find_or_create_by(name_string_id: ns.id, person_id: cc.person_id)

              logger.debug("\n ====AM-UPDATING CONTRIB #{cc.id} WITH PEN_NAME_ID CHANGE TO: #{npn.id} from #{cc.pen_name_id}====\n")
              cc.pen_name_id = npn.id
              cc.role = ns_hash[:role] # wns.role
              cc.save
            end
            
          end
          
        else
          logger.debug("\n\n ==== NO-EXISTING-CONTRIB: BUT COULD-HAVE AN ASSOCIATION-CREATED======\n")
        end
        
        # but if not found as an existing contrib
        # need to see if this name_string exists as a PenName
        # and if so, create a basic contrib record which will give a checkbox to the new name
        #
        # this may find nothing, which is okay
        
        logger.debug("n ==== SEARCHING-PENNAMES-FOR-NAME_STRING_MATCH ======\n")
        pnames = PenName.where(name_string_id: ns.id)
        pnames.each do |pns|
          # find the contributor, IF they exist for the: pen_name and work
          # and give them an initial linking
          
          
          logger.debug("\n===== pen_name_id: #{pns.id} for person: #{pns.person_id}  ON WORK: #{self.id} ====\n")
          
          contr = Contributorship.new
          contr.pen_name_id = pns.id
          contr.person_id = pns.person_id
          contr.work_id = self.id
          contr.role = 'Author' # defaulting
          contr.contributorship_state_id = 1
          contr.save
          logger.debug("\n ===== CREATING-NEW-CONTRIB ====\n")
          logger.debug(contr.inspect)
        end

      end
    end
    
    # then would need to delete any remaining work_name_strings from the existing work
    logger.debug("ANY REMAINING EXISTING WORK_NAME_STRINGS")
    logger.debug( self.work_name_strings.to_a.slice(counter, self.work_name_strings.length).inspect )
    
    # next should be one or the other, eg. either remaining_wns is not empty? or new names is bigger
    remaining_wns = self.work_name_strings.to_a.slice(counter, self.work_name_strings.length).nil? ? [] :
      self.work_name_strings.to_a.slice(counter, self.work_name_strings.length)
          
    if remaining_wns.empty?
      # any additional names added to this work, take advantage of existing code in a new method
      if counter < new_name_strings_hash.length
        add_new_name_strings_submission( new_name_strings_hash.slice(counter, new_name_strings_hash.length), counter )
      end
    
    else
      
      if names_to_skip.empty?
        # if there is a contributor, need to delete them as well
        remaining_wns.each do |rm_wns| 
          pids = PenName.where(:name_string_id => rm_wns.name_string_id) # may be more than one
          pids.each do |pid|
            cx = Contributorship.find_by_work_id_and_pen_name_id_and_role(rm_wns.work_id, pid.id, rm_wns.role)
            if cx
              logger.debug("\n\n === DELETING_CONTRIBUTOR: #{cx.inspect}")
              Contributorship.delete(cx.id)
            end
          end
        end
      
        # remove all the extra prior saved work_name_strings
        counter.upto(self.work_name_strings.length-1) do |x|
          logger.debug("DELETING WNS: #{self.work_name_strings[x].inspect}")
          self.work_name_strings[x].delete # also sets destroyed? flag 
        end
      end
      
    end
    
    # RE-ORDER IF NEC
    #sarr = new_name_strings_hash.collect{|item| item.to_a.flatten[5]}
    sarr = new_name_strings_hash.collect{|item| item[:wns_id] }
    
    logger.debug("\n\n=============LOOKING-AT-REORDER OF WNS ============\n")
    logger.debug(sarr.inspect)
    
    cnt=0
    unless [true] == sarr.collect{|it| cnt+=1; cnt == self.work_name_strings.find(it).position}.uniq 
      
      if new_name_strings_hash.collect{|x| x[:wns_id]}.compact.length == new_name_strings_hash.length
        logger.debug("\n\n ======== RE-ORDER-WORK_NAME_STRINGS ============ \n")
        new_name_strings_hash.each_with_index do |item, iteration|
          w = self.work_name_strings.find(item[:wns_id])
          unless w.position == iteration + 1
            w.update_column(:position, iteration + 1) 
            logger.debug("SAVING WID: #{w.id} => #{item[:wns_id]} to position: #{iteration + 1}")
          end
        end
        
      else
        logger.debug("\n\n======== WNS-NEEDS-REORDERING-BUT hash[:wns_id] is missing somewhere =======\n\n")
        logger.debug(new_name_strings_hash.inspect)
      end
      
    else
      logger.debug("\n\n ======== NOT NECESSARY TO RE-ORDER-WORK_NAME_STRINGS ============ \n")
    end
    
  end



  # This is new, but essentially the same as original/modified update_work_name_strings
  def add_new_name_strings_submission(name_strings_hash, counter)
    return unless name_strings_hash
    
    position = counter
    name_strings_hash.flatten.each do |cns|
      machine_name = make_machine_name(cns[:name])
      name = cns[:name].strip
      logger.debug("ADD_NEW_NAME_STRING_SUBMISSION: #{name}")
      position += 1
      
      ## new idea, when change is only in Case, Parry C. from Parry c.
      ## using varbinary on column may cause problems with index
      #if NameString.where(machine_name: machine_name, name: name).exists?
      #  exists= NameString.where(machine_name: machine_name, name: name).first
      #  unless (exists.name <=> name) == 0
      #    exists.name = name
      #    exists.save
      #  end
      #end
      
      name_string = NameString.find_or_create_by(machine_name: machine_name, name: name)
      
      ## March 08, 2016
      ## REMOVING FIND OR CREATE AS THERE MAY BE MORE THAN ONE WITH THE SAME NAME
      ## BUT IT COULD BE THAT A PERSON IS BOTH AN AUTHOR AND EDITOR
      ## SO I MAY NEED TO ADD NEW FUNCTIONALITY ONLY in the ELSE BELOW where it says "REQUIRED_PEN_NAME DOES NOT EXIST "
      ## new functionality required adding position to the unique validation in WorkNameString model
      
      logger.debug("\n\n CHECKING EXISTANCE OF CONTRIBUTOR FOR A WORK for work: #{self.id} ===============\n")
      if WorkNameString.where(name_string_id: name_string.id, role: cns[:role], work_id: self.id).exists?
        logger.debug(" ============= ADDING_ADDITIONAL_CONTRIBUTOR TO WORKNAME_STRING FOR THIS WORK =====\n\n")
        # IF THIS CALL FAILS it's because position being requested is already taken. the UNIQUE key requires distinct all of the following
        nwns = self.work_name_strings.create(name_string_id: name_string.id, role: cns[:role], position: position)
      else
        nwns = self.work_name_strings.find_or_create_by(name_string_id: name_string.id, role: cns[:role], position: position)
      end
      
      cns[:wns_id] = nwns.id
      
      # find the pen_name record for the new or existing name_string
      # an edit with a known pen name will make the association and the contrib get added
      pns = PenName.find_by_name_string_id(name_string.id) 
      if pns.blank? == false

        # find the contributor, if they exist for this person, work, and role
        con = Contributorship.find_by_person_id_and_work_id_and_role(pns.person_id, self.id, cns[:role])
        unless con.blank?
          logger.debug("== IN WORKS_MODEL_FOUND_CONTRIBUTOR ==")
          unless con.pen_name_id.eql?(pns.id)
            logger.debug("AM UPDATING ATTRIBUTES OF THIS CONTRIBUTOR")
            logger.debug(con.inspect)
            logger.debug("ASSIGNING_NEW_PEN_NAME_ID = #{pns.id} to #{con.id}")
            # update contributorship so that mapping to pen_name is updated and verify author works
            con.update_attributes(:pen_name_id => pns.id)
          end
        else
          # this would make the association programatically, bad idea, staff need to do it manually
          # and they can since work_name_string has been created
          #logger.debug("\n\n== CREATING NEW CONTRIBUTORSHIP IN WORKS_MODEL ==")
          #Contributorship.find_or_create_by_person_id_and_work_id_and_role_and_pen_name_id(pns.person_id, self.id, cns[:role], pns.id)
          logger.debug("\n\n ========= DO I ADD A POSSIBLE-CONTRIBUTORSHIP SINCE THIS PEN_NAME EXISTS")
          logger.debug("PenName found was: #{pns.inspect}")
          
          #contr = Contributorship.new
          #contr.pen_name_id = pns.id
          #contr.person_id = pns.person_id
          #contr.work_id = self.id
          #contr.role = 'Author' # defaulting
          #contr.contributorship_state_id = 1
          #contr.save
          
        end
        
      else
        logger.debug("\n\n ============= REQUIRED_PEN_NAME DOES NOT EXIST ==============\n\n")
        logger.debug("== I THINK STAFF HAVE TO CREATE THE PERSON FIRST, AND MAKE SURE THE PEN NAME EXISTS == \n\n")
      end
      
    end
    
  end

# Create WorkNameStrings, after a Work is created successfully
#  Called by 'after_create' callback
  def create_work_name_strings
    #Create any initialized name_strings and save to Work
    self.set_work_name_strings(@work_name_strings_cache) if @work_name_strings_cache
  end

  def set_initial_publisher(publisher)
    self.publisher = publisher.authority
    self.initial_publisher_id = publisher.id
  end

  def set_initial_publication(publication)
    self.publication = publication.authority
    self.initial_publication_id = publication.id
  end

  def get_start_page(value)
    #return "" if value.nil? || value.empty?
    #start_page = value.to_s
    start_page = get_attribute_dupe_info('start_page') 
      
    # some lousy ris formatted data aren't correctly parsed (in one case, synapse python-based original)
    start_page = start_page.split('-')[0].to_s.strip if start_page.include?('-') 
    return start_page
  end
  
  # found this to be the case when a dupe key is created before the attributes are saved
  # in what is a very convuluted process 
  def get_attribute_dupe_info(attr_name)
    attrib = case self.send(attr_name).nil?
    when true 
      self.attributes[attr_name].to_s ||= ''
    else
      self.send(attr_name).to_s
    end
  end

  # Adding
  def pen_names_submit_diff(x,y)
    o = x
    x = x.reject{|a| if y.include?(a); a end }
    y = y.reject{|a| if o.include?(a); a end }
    x | y
  end

end
