require 'set'

class Contributorship < ApplicationRecord
  
  attr_accessor :skip_refresh_contributorships

  STATE_UNVERIFIED = 1
  STATE_VERIFIED = 2
  STATE_DENIED = 3

  #### Associations ####
  belongs_to :person
  belongs_to :work
  belongs_to :pen_name

  #### Named Scopes ####
  #Various Contributorship statuses
  scope :unverified, -> { where contributorship_state_id: STATE_UNVERIFIED }
  scope :verified, -> { where contributorship_state_id: STATE_VERIFIED }
  scope :denied, -> { where contributorship_state_id: STATE_DENIED }
  scope :visible, -> { where hide: false, role: "Author" }
  #By default, show all verified, visible contributorships
  scope :to_show, -> { where hide: false, contributorship_state_id: STATE_VERIFIED }
  #All contributorships for a specified work or person
  scope :for_work, lambda { |work_id| where(work_id: work_id) }
  scope :for_person, lambda { |person_id| where(person_id: person_id) }

  #### Validations ####
  validates_presence_of :person_id, :work_id, :pen_name_id
  validates_uniqueness_of :work_id, :scope => :person_id

  #### Callbacks ####
  before_validation :set_initial_states, :on => :create
  #after_create :calculate_initial_score
  after_save :after_save_actions

  def after_save_actions
    logger.debug("\n=== REFRESHING_CONTRIBUTORSHIP_STATUS AFTER SAVE===\n")
    self.refresh_contributorships
  end

  ## Note: no 'after_destroy' is necessary here, as PenNameObserver
  ## takes care of updating Solr before destroying Contributorships
  ## associated with a PenName.

  ##### Contributorship State Methods #####
  def set_initial_states
    # All Contributions start with:
    # * state - "Unverified"
    # * hide  - 0 (false)
    # * score - 0 (zero)
    self.contributorship_state_id = STATE_UNVERIFIED
    self.hide = false
    self.score = 0
  end
  
  def unverified?
    self.contributorship_state_id == STATE_UNVERIFIED
  end

  def unverify_contributorship
    #self.contributorship_state_id = STATE_UNVERIFIED
    ## if the contributorship is going from denied -> unverified
    ## we need it to be unhidden
    #self.hide = false
    #self.save
    update_attribute_solr(STATE_UNVERIFIED, false)
  end

  def verified?
    self.contributorship_state_id == STATE_VERIFIED
  end

  def verify_contributorship
    #self.contributorship_state_id = STATE_VERIFIED
    ## if the contributorship is going from denied -> verified
    ## we need it to be unhidden
    #self.hide = false
    #self.save
    update_attribute_solr(STATE_VERIFIED, false)
  end

  def denied?
    self.contributorship_state_id == STATE_DENIED
  end

  def deny_contributorship
    ## Denying a Contributorship requires following
    ## 1. Set state to "Denied"
    ## 2. Set hide to "true"
    ## 3. Set score to "zero"
    #self.contributorship_state_id = STATE_DENIED
    #self.hide = true
    #self.score = 0
    #self.save
    self.update_column(:score, 0) # and not really using anymore anyway
    update_attribute_solr(STATE_DENIED, true)
  end
  
  # as this is user-initiated action, not part of bulk process
  # avoid callback in contrib.save which assigns contrib to DJ queue
  def update_attribute_solr(state, hidden)
    self.update_column(:contributorship_state_id, state)
    self.update_column(:hide, hidden)
    
    # direct without going through DJ, though work is put in DJ 
    Person.find(self.person_id).update_contributorship_status(self.work_id) 
  end

  def visible?
    self.hide == false
  end


#  ########## Methods ##########
#  def calculate_score(person_scoring_hash = nil)
#
#    # Build the calculated Contributorship.score attribute--a rough
#    # guess whether we think the Person has written the Work
#    #
#    # Field           Value   Scoring Algorithm
#    # ---------------------------------------------
#    # Years            25      If matches = 25 pts
#    # Publications     25      If matches = 25 pts
#    # Collaborators    25      (25/total) * matching
#    # Keywords         25      (25/total) * matching
#
#    # Observations (EL):
#    # Looks to work pretty well.  I tested this against:
#    # * Morgan, D - Dane D Morgan - Engineering Physics
#    # * Morgan, D - David Morgan  - History Department
#    #
#    # The two faculty really separate between Collaborators and Keywords
#
#    # @TODO:
#    # 1. Crontask / Asynchtask to periodically adjust scores
#
#    person_scoring_hash ||= self.person.scoring_hash
#    work_scoring_hash = self.work.scoring_hash
#
#    if person_scoring_hash and work_scoring_hash
#      year_score = calculate_year_score(person_scoring_hash, work_scoring_hash)
#      publication_score = calculate_publication_score(person_scoring_hash, work_scoring_hash)
#      collaborator_score = calculate_collaborator_score(person_scoring_hash, work_scoring_hash)
#      keyword_score = calculate_keyword_score(person_scoring_hash, work_scoring_hash)
#      self.score = (year_score + publication_score + collaborator_score + keyword_score)
#    else
#      self.score = 0
#    end
#  end
#
#  def calculate_keyword_score(person_scoring_hash, work_scoring_hash)
#    calculate_inclusion_score(person_scoring_hash[:keyword_ids], work_scoring_hash[:keyword_ids], 25)
#  end
#
#  def calculate_collaborator_score(person_scoring_hash, work_scoring_hash)
#    calculate_inclusion_score(person_scoring_hash[:collaborator_ids], work_scoring_hash[:collaborator_ids], 25)
#  end
#
#  #return 0 if the possible ids are empty, otherwise max_score * the fraction of possible_ids in known_ids
#  def calculate_inclusion_score(known_ids, possible_ids, max_score)
#    return 0 if possible_ids.empty?
#    known_ids = known_ids.to_set
#    matches = possible_ids.select do |id|
#      known_ids.include?(id)
#    end
#    return ((max_score / possible_ids.size) * matches.size)
#  end
#
#  def calculate_publication_score(person_scoring_hash, work_scoring_hash)
#    return 25 if person_scoring_hash[:publication_ids].include?(work_scoring_hash[:publication_id])
#    return 0
#  end
#
#  def calculate_year_score(person_scoring_hash, work_scoring_hash)
#    work_year = work_scoring_hash[:year]
#    years_array = person_scoring_hash[:years].compact.sort
#    return 0 if years_array.empty?
#    year_range = Range.new(years_array.first, years_array.last)
#    return (year_range.include?(work_year) ? 25 : 0)
#  end

  #def calculate_initial_score
  #  calculate_score
  #  save
  #end

  # Get a count of other unverified contributorships for current Work
  def candidates
    Contributorship.unverified.for_work(self.work_id).size
  end

  # Get a count of possible Person matches to contributorships for current Work
  def possibilities
    logger.debug("\n=== Possibilities ===\n")
    Contributorship.for_work(self.work_id).inject(0) do |acc, c|
      # this check will fix delayed_job errors, but not sure I want it at this point
      #if c.pen_name
        acc + self.work.name_strings.where(:name => c.pen_name.name_string.name).count
      #end
    end
  end

  def refresh_contributorships
    # After save method
    # If verified.size == possibilities.size
    # - Loop through competing Contributorships
    # - Set Contributorship.hide == true
    
    logger.debug("\n\n IN_REFRESH_CONTRIBUTORSHIP with #{self.inspect} +AND+ skip_refresh_contributorships == #{self.skip_refresh_contributorships}")
    return if self.skip_refresh_contributorships

    # of the possible contributors for a work (that means verified or not verified)
    # if that count is the same as the count of verified authors for the work
    poss_count = self.possibilities
    if Contributorship.verified.for_work(self.work_id).size == poss_count
      
      # for those who aren't this particular person id <> self.id
      logger.debug("\n\n=== POTENTIALLY REFRESHING_CONTRIBUTORSHIPS of this work === \n")
      
      refresh = Contributorship.for_work(self.work).unverified.where('id <> ?', self.id)
      logger.debug("Found #{refresh.length} unverified contributorships for contributor: #{self.id}, work: #{self.work.id}: #{self.work.machine_name}")
      
      #This previously used save_without_callbacks
      #In this case there is a possibility that removing it will cause an infinite recursion - I'm not sure
      # EM, going back to update with callbacks
      refresh.each do |r|
        logger.debug("\n == SETTING_HIDE to true for: #{r.inspect}")
        #r.hide = true
        #r.skip_refresh_contributorships = true
        #r.save
        r.update_column(hide: true)
      end
    end

    ## Update Person's scoring hash
    #logger.debug("\n=== Updating scoring hash ===\n")
    #self.person.update_scoring_hash
    
    unless Delayed::Job.where(delayed_reference_id: self.person.id).exists?
      logger.debug("\n\n ============== SETTING CONTRIBUTORSHIP_STATUS for PERSON.id #{self.person.id} =========")
      Delayed::Job.enqueue ProcessPersonContributorshipDelayedJob.new(self.person.id, self.work.id)
    else
      logger.debug("\n===========QUEUE ALREADY_EXISTS CONTRIBUTORSHIP_STATUS for PERSON.id #{self.person.id} =========")
    end
    
    ## moving this to above DJ process
    #unless Delayed::Job.where(delayed_reference_id: self.work.id, delayed_reference_type: self.work.type).exists?
    #  logger.debug("\n ==== ENQUEUEING DJ QUEUE FOR WORK.id #{self.work.id} of person.id #{self.person.id}")
    #  Delayed::Job.enqueue ProcessWorksDelayedJob.new(self.work.id, self.work.type)
    #else
    #  logger.debug("\n===========QUEUE ALREADY_EXISTS--WORK for Contributor #{self.person.id} not adding work.id: #{self.work.id} ===\n")
    #end
    
  end
  
  def self.unverified_articles_by_year(state = 1)
    sql = "SELECT works.publication_date, works.title_primary, works.id as 'Workid', " + 
        "YEAR(works.publication_date) as 'Year', identifiers.name as source, works.import_job_id, " + 
        "works.created_at as created, contributorships.* FROM works LEFT JOIN contributorships ON works.id = contributorships.work_id " + 
        "INNER JOIN identifyings on works.id = identifyings.identifiable_id INNER JOIN identifiers on identifyings.identifier_id = identifiers.id " + 
        "WHERE ((contributorships.contributorship_state_id = ? OR contributorships.contributorship_state_id is NULL) " +
        "and identifyings.identifiable_type = 'Work' and identifiers.type = 'provider') " +
        "GROUP BY works.id ORDER BY Year desc, works.created_at asc" # this picks up dupe titles AUG272015
        #"GROUP BY works.title_primary, Year ORDER BY Year desc, works.created_at asc" # was original
        #"GROUP BY works.title_primary ORDER BY works.publication_date desc, works.created_at asc"
      
        #arr = Contributorship.find_by_sql([sql, state])
        #return arr.delete_if{|x| x.work_id.nil?}
    return Contributorship.find_by_sql([sql, state])
  end

  def self.unverified_articles_year_counts(state = 1)
    sql = "SELECT YEAR(works.publication_date) as 'Year' FROM works LEFT JOIN contributorships ON works.id = contributorships.work_id " +
        "INNER JOIN identifyings on works.id = identifyings.identifiable_id INNER JOIN identifiers on identifyings.identifier_id = identifiers.id " +
        "WHERE ((contributorships.contributorship_state_id = ? OR contributorships.contributorship_state_id is NULL) " +
        "and identifyings.identifiable_type = 'Work' and identifiers.type = 'provider') GROUP BY works.id, Year" # match by ID AUG2015
        #"and identifyings.identifiable_type = 'Work' and identifiers.type = 'provider') GROUP BY works.title_primary, Year"
  
    hsh = Hash.new
    arr = Contributorship.find_by_sql([sql, state])
  
    arr.each do |rec|
      yr = rec['Year']
      if hsh.has_key?(yr)
        hsh[yr] += 1
      else
        hsh[yr] = 1
      end
    end
  
    return hsh
  end
  
end