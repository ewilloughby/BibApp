class Publication < PubCommon
  #### Associations ####

  # setting foreign key to optional as per rails 5 change for both publisher and authority
  belongs_to :publisher, class_name: "Publisher", foreign_key: :publisher_id, optional: true
  # this is referencing itself in many cases, or about 2/3 of the time
  belongs_to :authority, class_name: "Publication", foreign_key: :authority_id, optional: true
  has_many :works, -> { where("work_state_id = ?", Work::STATE_ACCEPTED) } #accepted works

  has_many :identifyings, as: :identifiable
  has_many :identifiers, through: :identifyings

  # This is necessary due to very long titles for conference
  # proceedings. For example:
  # Cultivating the future based on science. Volume 1: Organic Crop
  # Production. Proceedings of the Second Scientific Conference of the
  # International Society of Organic Agriculture Research (ISOFAR), held at
  # the 16th IFOAM Organic World Conference in Cooperation with the
  # International Federation of Organic Agriculture Movements (IFOAM) and
  # the Consorzio ModenaBio in Modena, Italy, 18-20 June, 2008
  validates_length_of :name, :maximum => 255,
                      :too_long => "is too long (maximum is 255 characters): {{value}}"

  #### Callbacks ####
  after_create :initialize_authority_id
  before_create :before_create_actions
  before_save :before_save_actions
  after_save :update_authorities
  after_save :reindex_callback, :if => :do_reindex

  #### Scopes ####
  scope :authorities, -> { where("id = authority_id") }
  scope :for_authority, lambda { |authority_id| where(:authority_id => authority_id) }
  scope :order_by_name, -> { order('name ASC') }
  scope :sort_name_like, lambda { |name| where('sort_name like ?', name.downcase) }
  scope :name_like, lambda { |name| where('name like ?', name) }

  # try limiting to pubs with works
  #scope :with_works,  lambda { |work| where('publication_id = ?', work.id).exists? }
  
  def before_create_actions
    unless self.initial_publisher_id.nil?
      self.publisher_id = Publisher.find(self.initial_publisher_id).authority.id
    end
  end

  def before_save_actions
    self.update_machine_name
    update_sort_name
    self.parse_identifiers
  end

  #### Methods ####
  
  # is this a fix for encoding issues as was done in name_strings 
  # if errors out at least staff will be alerted on bad character in name
  def name=(aname)
    write_attribute(:name, aname.nil? ? nil : aname.force_encoding('UTF-8').encode('UTF-8') )
  end   

  def validate_name
    "#{self.name} #{self.issn_isbn}".downcase.gsub(/[^a-zA-Z0-9]+/, "")
  end

  def publisher_name
    publisher.name if publisher
  end

  def publisher_name=(name)
    name ||= 'Unknown'
    self.publisher = Publisher.find_or_create_by(name: name, romeo_color: 'unknown') unless name.blank?
  end

  def isbns
    self.identifiers.where(:type => 'ISBN').collect { |isbn| {:name => isbn.name, :id => isbn.id} }
  end

  def issns
    self.identifiers.where(:type => 'ISSN').collect { |issn| {:name => issn.name, :id => issn.id} }
  end

  def parse_identifiers
    return if self.issn_isbn.blank?

    # Field might be separated
    issn_isbn.split("; ").each do |identifier|

      # No spaces, no hyphens, no quotes
      identifier = identifier.strip.gsub(/[-" ]/, "")

      # Init new Identifier
      parsed_identifiers = Identifier.parse(identifier)
      parsed_identifiers.each do |pi|
        klass, id = pi
        #pub_id = Identifier.find_or_create_by_name_and_type(id, klass.id_type_string)
        pub_id = Identifier.find_or_create_by(name: id, type: klass.id_type_string)
        unless self.identifiers.include?(pub_id)
          self.identifiers << pub_id
        end
      end

    end
  end

  def form_select
    "#{name.first(100)}... - #{issn_isbn}"
  end

  def authority_for_work_count
    Work.accepted.for_authority_publication(self.id).count
  end

  #Update authorities for related models, when Publication Authority changes
  # (called by after_save callback)
  def update_authorities
    # If Publication authority changed, we need to echo new authority key
    # to each related model.
    logger.debug("\n\nPub: #{self.id} | Auth: #{self.authority_id}\n\n")
    if (self.saved_change_to_attribute?(:authority_id) and self.authority_id != self.id) or
       self.saved_change_to_attribute?(:publisher_id)

      # Update publications
      logger.debug("\n\n===Updating Publications===\n\n")
      self.authority_for.each do |pub|
        pub.authority_id = self.authority_id
        pub.save
      end

      # Update works
      logger.debug("\n\n===Updating Works===\n\n")
      self.works.each do |work|
        work.publication_id = self.authority_id
        work.publisher_id = self.authority.publisher.authority_id
        work.set_for_index_and_save
      end
      self.do_reindex = true
    end
  end

  #Parse Solr data (produced by to_solr_data)
  # return Publication name and ID
  def self.parse_solr_data(publication_data)
    if publication_data.blank?
      return nil, nil
    else
      name, id = publication_data.split("||")
      return name.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8).html_safe, id
    end
  end
  
  # SELECT distinct publications.* FROM publications LEFT OUTER JOIN works ON works.publication_id = publications.id AND
  # (works.work_state_id = 3) WHERE (publications.id = authority_id) AND (works.publication_id = publications.id) AND
  # (publications.sort_name like '1%');
  def self.having_works(page)
    sql = "SELECT distinct publications.* FROM publications LEFT OUTER JOIN works ON works.publication_id = publications.id " +
    "AND works.work_state_id = 3 WHERE publications.id = authority_id AND works.publication_id = publications.id " +
    "AND publications.sort_name like ? ORDER BY publications.sort_name"
    
    self.find_by_sql([sql, page])
  end
  
end
