require 'string_methods'
class Import < ActiveRecord::Base
  cattr_reader :per_page
  @@per_page = 10

  # ActiveRecord Attributes
  # attr_protected :state
  serialize :works_added
  serialize :import_errors

  # ActiveRecord Associations
  belongs_to :user
  # Do imports belong to person? Taking this out for now
  #belongs_to :person

  has_one :import_file, :as => :asset, :dependent => :destroy

  after_create :after_create_actions

  # ActiveRecord Callbacks
  def after_create_actions
    self.process!
  end

  # Acts As State Machine
  include AASM
  aasm :column => :state do
    state :received, :initial => true
    state :processing, :after_enter => :queue_import
    state :reviewable, :after_enter => :notify_user
    state :accepted, :after_enter => :accept_import
    state :rejected, :after_enter => :reject_import
    state :aborted, :after_enter => :abort_import
    event :process do
      transitions :to => :processing, :from => :received
    end
    event :review do
      transitions :to => :reviewable, :from => :processing
    end
    event :accept do
      transitions :to => :accepted, :from => :reviewable
    end
    event :reject do
      transitions :to => :rejected, :from => :reviewable
    end
    event :abort do
      transitions :to => :aborted, :from => :processing
    end
  end

  def notify_user
    logger.debug("\n=== Notify User - #{self.id} ===\n\n\n")
    current_locale = I18n.locale
    I18n.locale = self.user.default_locale
    # trying deliver_later as deliver is deprecated with ROR5, uses ActiveJob
    #Notifier.import_review_notification(self).deliver
    Notifier.import_review_notification(self).deliver_later
    I18n.locale = current_locale
  end

  def abort_import
    logger.warn("\n\n====== IN IMPORT.ABORT_IMPORT ======\n")
    logger.warn(" #{self.class.to_s} with id: #{self.id}")
    logger.warn(" #{self.inspect}")
    notify_user
  end

  def accept_import
    
    logger.debug("\n\n====== IN IMPORT.ACCEPT_IMPORT ======\n")
    logger.debug(" #{self.class.to_s} with id: #{self.id}")
    
    # which gets called, DJ explicitly or ActiveJob
    # can I change this to self.process_later(process_accepted_import)
    #self.delay.process_accepted_import
    ProcessAcceptedImportsJob.perform_later(self)
  end

  def process_accepted_import
    logger.debug("\n=== Accepted Import - #{self.id} ===\n\n")
    works = Work.where("id in (?)", self.works_added)

    # Create unverified contributorships for each non-duplicate work
    works.each { |w| w.create_contributorships }

    # If import was for a Person, auto-verify the contributorships
    if self.person_id
      person = Person.find(person_id)
      logger.debug("\n\n\n* Auto-verify contributorships - #{self.person_id}\n\n")

      # Find Contributorships, set to verified.
      contributorships = works.collect do |work|
        Contributorship.find_or_create_by_work_id_and_person_id(work.id, self.person_id)
      end

      contributorships.each do |c|
        c.verify_contributorship
        c.work.set_for_index_and_save
      end

      logger.debug("\n\n\n* Batch indexing import - #{self.person_id}\n\n")
      Index.batch_index

      #Delayed Job - Update scoring hash for Person
      person.delay.queue_update_scoring_hash
    end
  end

  def reject_import
    logger.debug("\n=== Rejected Import - #{self.id} ===\n\n")
    logger.debug("\n* Destroying Import Works")

    self.works_added.each do |work_added|
      work = Work.find_by_id(work_added)
      logger.debug("\n- Work: #{work.id}") if work
      work.delay.destroy if work
    end

    self.works_added = []
  end

###
# ===== Import Object Methods =====
###

# Add Import to Delayed Job queue
  def queue_import
    self.delay.batch_import
  end

# Process Batch Import
def batch_import
  return unless self.state == 'processing'
  
  self.transaction do
    logger.info("\n\n==== Starting Batch Import ==== \n\n")
  
    #ppparsers = CitationParser.parsers
    #logger.info("CITATIONPARSERS: #{ppparsers.inspect}")
    # CITATIONPARSERS: [BaseXmlParser, EndNoteRisParser, MedlineParser, RefworksXmlParser, RisParser]

    # Initialize an array of all the works added and hash of errors encountered in the batch
    self.works_added = Array.new
    self.import_errors = Hash.new

    # Init: Parser and Importer
    citation_parser = CitationParser.new
    citation_importer = CitationImporter.new

    # Step: 1 -- Read the data
    begin
      begin
        # unicode_normalize added
        # unicode_normalize(:nfc) where NFC preserves glyphs and NFKC turns some into ASCII and NFKD turns into two glyphs
        # https://wiki.qt.io/Basics_of_String_Encoding
        # 
                
        #str = StringMethods.ensure_utf8(self.read_import_file.unicode_normalize(:nfkd))
        str = StringMethods.ensure_utf8(self.read_import_file)
        if str.respond_to?(:unicode_normalize)
          str = str.unicode_normalize(:nfkd)
        else
          raise Exception.new("Could not determine file type")
        end
      
        # remove any BOM, above was supposed to ??
        str.sub!(/^\xEF\xBB\xBF/, '')
        #str.delete!(/^\xEF\xBB\xBF/)

      rescue EncodingException => e
        logger.warn("StringMethods.ensure_utf8 failed. Raising exception")
        self.import_errors[:invalid_file_format] = 
          "Citations could not be parsed as the character encoding could not be determined or could not be converted to UTF-8."
        
        self.import_errors[:exception] = e.to_s
        self.update_column(:import_errors, self.import_errors)
        self.abort!
        return
      
      rescue Exception => e
       
        logger.warn("Raising Standard exception: #{e.to_s}")
        self.import_errors[:exception] = e.to_s
        
        self.update_column(:import_errors, self.import_errors)
        self.abort!
        return
      end
    
      if citation_parser.respond_to?(:msk_endnote_filetype) 
        ifile = self.import_file_type.nil? ? 'unknown' : self.import_file_type

        if %w{scopus wos biosis cinahl psycinfo books}.include?(ifile)
          citation_parser.msk_endnote_filetype = ifile
          logger.warn("\n\nParser.msk_endnote_filetype: #{citation_parser.msk_endnote_filetype}\n\n")

          if check_endnote_for_msk(str) == false
            logger.warn("File was not processed with the EndNote BibApp filter or #{ifile} style")
            self.import_errors[:invalid_file_format] = 
              "It looks like the file was not processed with the EndNote BibApp filter or #{ifile} style"
            self.save
            self.review!
            return
          end
        else
          logger.warn("\nNot processing #{ifile} as an EndNote RIS Bibapp file\n")
        end
      end

      logger.warn("\nCalling CitationParser.parse in imports model\n")

      parsed_citations = citation_parser.parse(str)

      logger.warn("\nFinished CitationParser, no runtime error.\n")
    
    rescue Exception => e
      logger.warn("Raising exception in begin block: #{e.to_s}")
      self.import_errors[:exception] = e.to_s
      self.update_column(:import_errors, self.import_errors)
      self.abort!
      return
    end

    if parsed_citations.blank?
      self.import_errors[:no_parsed_citations] = <<-MESSAGE
      The format of the input was unrecognized or unsupported.
      <br/><strong>Supported formats include:</strong> RIS, MedLine and Refworks XML.<br/>
      In addition, if you are uploading a text file, it should use UTF-8 character encoding.
      MESSAGE
      self.save_and_review!
      return
    end
  
    logger.warn("\n\nParsed Citations: #{parsed_citations.size}\n\n")
    logger.debug("\n\n== IN MODEL.IMPORT, showing parsed_citations ===\n\n")
    logger.debug(parsed_citations.inspect)
  

    begin
  
      #import citations
      logger.debug("\n\n== CALLING CitationImporter.citation_attribute_hashes from import model ==\n\n")
      attr_hashes = citation_importer.citation_attribute_hashes(parsed_citations)
      logger.debug "\n#{attr_hashes.size} Attr Hashes: #{attr_hashes.inspect}\n\n\n"
  
      # Make sure there is data in the Attribute Hash
      return nil if attr_hashes.nil?

      #create works and reindex
      logger.debug("\n\n============ CREATE_WORKS_FROM_ATTRIBUTE_HASHES ==========\n")
      create_works_from_attribute_hashes(attr_hashes)
      logger.debug("\n\n============ CALLING_INDEX_BATCH_INDEX FOR WORKS ==========\n")
      # this is not doing anything since batch_index work attribute has not been set to 1 (FEB 2016)
      logger.debug("WORKS COUNT for BATCH INDEXING: #{Work.to_batch_index.length}")
      Index.batch_index # THIS IS FOR WORKS

    rescue Exception => e
      # import_errors is a field in the Imports table
      ##re-raise this exception to create()...it will handle logging the error
      if e.respond_to?(:backtrace)
        self.import_errors[:exception] = e.message + "\n\n++++ BACKTRACE\n\n" + e.backtrace.to_s
      else
        self.import_errors[:exception] = e.message 
      end
    end

    # At this point, some or all of the works were saved to the database successfully.
    self.save_and_review!
  end
    
end

  def save_and_review!
    self.save
    self.review!
  end

  def read_import_file
    File.read(self.import_file.absolute_path)
  end

# Create works in database. Use a transaction to rollback if there is an error, allowing error to propagate
  def create_works_from_attribute_hashes(attr_hashes)
    self.transaction do
      attr_hashes.each do |h|
        begin
          work = Work.create_from_hash(h, false)
          logger.debug("\n\n====== CREATING WORK FROM HASH #{h[:title_primary]}======\n")
          if work.errors.blank?
            #add to batch of works created
            self.works_added << work.id
          else #validation problem
            self.import_errors[:import_error] ||= Array.new
            self.import_errors[:import_error] << "<em>#{h[:title_primary]}</em> could not be imported. #{work.errors.to_s}<br/>"
          end
        rescue Exception => e
          #actual exception
          self.import_errors[:import_error] ||= Array.new
          self.import_errors[:import_error] << "<em>#{h[:title_primary]}</em> could not be imported. #{e.to_s}<br/>"
        end
      end
    end
  end

  def name_string_work_count
    works = self.works_added.collect { |work_id| Work.find_by_id(work_id) }.compact

    # Initialize hash of name_strings
    name_strings = Hash.new

    works.each do |work|
      work.name_strings.each do |ns|
        name_strings[ns.name] ||= {:id => ns.id, :works => []}
        name_strings[ns.name][:works] << work.id
      end
    end

    return name_strings
  end

end
