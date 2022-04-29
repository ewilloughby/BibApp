#This is an awful name for a class, but the result will be good.
#This aims to abstract out common code from Publication and Publisher,
#of which there is a good deal.
require 'machine_name'
require 'stop_word_name_sorter'
require 'solr_helper_methods'
require 'solr_updater'

class PubCommon < ApplicationRecord
  self.abstract_class = true

  include MachineNameUpdater
  include StopWordNameSorter
  include SolrHelperMethods
  include SolrUpdater

  attr_accessor :do_reindex

  # Convert object into semi-structured data to be stored in Solr
  def to_solr_data
    "#{name}||#{id}".force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8)
  end

  def authority_for
    logger.debug("\n\n ============= CALLING_PUB_COMMON_AUTHORITY_FOR with #{self.id} and #{self.class.to_s} ====\n")
    self.class.for_authority(self.id)
  end

  def solr_filter
    %Q(#{self.class.to_s.downcase}_id:"#{self.id}")
  end

  # SEE NOTE BELOW, what would be indexed here
  def reindex_callback
    Index.batch_index
  end

  # return the first letter of each name, ordered alphabetically
  def self.letters(upcase = nil)
    letters = self.select('DISTINCT SUBSTR(name, 1, 1) AS letter').order('letter').collect { |x| x.letter } - [' ']
    letters = letters.collect { |x| x.upcase rescue x }.uniq.sort if upcase
    return letters
  end


  # TODO with SOLR 6.2
  # CAN I simplify the SOLR update, and not update the entire work 
  # NEED TO ALSO DETERMINE HOW THIS CALL IS DIFFERENT FROM UPDATING A BATCH OF NEW WORKS
  # (unless I can determine that only fields relating to Pen Name will be updated)
  #  if only the person related things have changed I can do add and set for partial updates directly
  # also see same logic in models/pen_name.rb

  # being called from publication and publisher controllers
  def self.update_multiple(pub_ids, auth_id)
    pub_ids.each do |pub|
      update = self.find_by_id(pub)
      update.authority_id = auth_id
      update.do_reindex = false
      update.save
    end
    
    # what would be indexed cause the work may not have changed?? haven't tested
    Index.batch_index
  end

  def get_associated_works
    self.works
  end

  def require_reindex?
    self.authority_id_changed? or self.name_changed? or self.machine_name_changed?
  end

  def initialize_authority_id
    self.authority_id = self.id
    self.save
  end

end