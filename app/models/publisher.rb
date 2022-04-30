require 'open-uri'
require 'net/http'

class Publisher < PubCommon
  #### Associations ####

  has_many :publications
  # setting this to optional as was in prior versions
  belongs_to :authority, class_name: "Publisher", foreign_key: :authority_id, optional: true

  has_many :works, -> { where("work_state_id = ?", Work::STATE_ACCEPTED) } #accepted works

  ROMEO_COLORS = ['blue', 'yellow', 'green', 'white', 'gray', 'unknown']

  validates_inclusion_of :romeo_color, :in => ROMEO_COLORS

  #### Callbacks ####
  before_validation :set_initial_states, :on => :create
  after_create :initialize_authority_id
  before_create :update_authorities
  before_save :update_machine_name
  before_save :update_sort_name
  after_save :update_authorities
  after_save :reindex_callback, :if => :do_reindex

  #### Scopes ####
  scope :authorities, -> { where("id = authority_id") }
  scope :for_authority, lambda { |authority_id| where(:authority_id => authority_id) }
  scope :order_by_name, -> { order('name ASC') }
  scope :name_like, lambda { |name| where('name like ?', name) }
  scope :sort_name_like, lambda { |name| where('sort_name like ?', name.downcase) }

  #### Methods ####

  SHERPA_SOURCE = 1
  IMPORT_SOURCE = 2

  def set_initial_states
    self.publisher_source_id = IMPORT_SOURCE # Import Data
  end

  def sherpa_color_or_unknown_as_sym
    self.romeo_color.to_sym rescue :unknown
  end

  #Update authorities for related models, when Publisher Authority changes
  # (called by after_save callback)
  def update_authorities
    # If Publisher authority changed, we need to echo new authority key
    # to each related model.
    logger.debug("\n\nPub: #{self.id} | Auth: #{self.authority_id}\n\n")
    if self.saved_change_to_attribute?(:authority_id) and self.authority_id != self.id

      # Update publishers
      logger.debug("\n\n===Updating Publishers===\n\n")
      self.authority_for.each do |pub|
        pub.authority_id = self.authority_id
        pub.save
      end

      # Update publications
      logger.debug("\n\n===Updating Publications===\n\n")
      self.publications.each do |publication|
        publication.publisher_id = self.authority_id
        publication.save
      end

      # Update works
      logger.debug("\n\n===Updating Works===\n\n")
      self.publications.each do |publication|
        publication.works.each do |work|
          work.publisher_id = self.authority_id
          work.set_for_index_and_save
        end
      end

      self.do_reindex = true
    end
  end

  def self.update_sherpa_data

    # First check that solr is running
    # We need it to be in order for the new publishers to be indexed
    begin
      n = Net::HTTP.new('localhost', SOLR_PORT)
      n.request_head('/').value

    rescue Errno::ECONNREFUSED, Errno::EBADF, Errno::ENETUNREACH #not responding
      puts "Warning: Updating Sherpa data requires Solr to be running. Exiting...\n"

    rescue Net::HTTPServerException #responding

      # SHERPA's API is not-cached! Opening the URI directly will likely
      # produce a ruby net/http timeout.
      #
      # Todo:
      # 1. Offer a cached copy within /trunk?
      # 2. Add directions for placing a copy within /tmp/sherpa/publishers.xml
      #
      # UPDATE:
      # The SHERPA API has gotten better, and requests are no longer timing
      # out. Unless those problems reemerge, it's probably safe to download
      # the SHERPA data via net/http.

      sherpa_response = Net::HTTP.get_response(URI.parse($SHERPA_API_URL))
      data = Nokogiri::XML::Document.parse(sherpa_response.body)
      data.css('romeoapi publishers publisher').each do |pub|
        sherpa_id = pub['id']
        name = pub.at_css('name').text
        url = pub.at_css('homeurl').text
        romeo_color = pub.at_css('romeocolour').text
        
        # SHOULD CHECK THIS 
        # this is ODD code, find or create expects unknown romeo color, and then updates it's attributes
        #add = Publisher.find_or_create_by_sherpa_id(:sherpa_id => sherpa_id, :romeo_color => 'unknown')
        add = Publisher.find_or_create_by(sherpa_id: sherpa_id, romeo_color: 'unknown')
        add.update_attributes!({:name => name, :url => url, :romeo_color => romeo_color,
                                :sherpa_id => sherpa_id, :publisher_source_id => SHERPA_SOURCE})
      end
      return true

    rescue
      puts "Unexpected Error: #{$!.class.to_s} #{$!}"
      raise
    end

  end

  #Parse Solr data (produced by to_solr_data)
  # return Publisher name and ID
  def self.parse_solr_data(publisher_data)
    if publisher_data
      name, id = publisher_data.split("||")
    else
      name = "Unknown"
      id = nil
    end
    return name.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8).html_safe, id
  end
  
  def self.having_works(page)
    sql = "SELECT distinct publishers.* FROM publishers LEFT OUTER JOIN works ON works.publisher_id = publishers.id AND " +       
    "works.work_state_id = 3 WHERE publishers.id = authority_id AND works.publisher_id = publishers.id " +
    "AND publishers.sort_name like ? ORDER BY publishers.sort_name"
    
    self.find_by_sql([sql, page])
  end
  
  # as with publication
  def name=(aname)
    write_attribute(:name, aname.nil? ? nil : aname.force_encoding('UTF-8').encode('UTF-8'))
  end   

end