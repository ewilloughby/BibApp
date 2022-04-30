require 'machine_name'
require 'namecase'

class NameString < ApplicationRecord
  include MachineName

  #### Associations ####
  #has_many :works, through: :work_name_strings
  #has_many :work_name_strings, dependent: :destroy
  #has_many :people, through: :pen_names
  #has_many :pen_names
  
  # switching order for Rails 5+
  has_many :work_name_strings, dependent: :destroy
  has_many :works, through: :work_name_strings
  has_many :pen_names
  has_many :people, through: :pen_names
  
  #### Callbacks ####

  #### Named Scopes ####
  #scope :order_by_name, order('name')
  scope :order_by_name, -> { order('name ASC') }
  scope :name_like, lambda { |name| where('name like ?', "%#{name}%") }

  before_save :update_machine_name

  # return the first letter of each name, ordered alphabetically
  def self.letters
    self.select('DISTINCT SUBSTR(name, 1, 1) AS letter').order('letter').collect {|x| x.letter}
  end

  #Parse Solr data (produced by to_solr_data)
  # return NameString name and ID
  def self.parse_solr_data(name_string_data)
    data = name_string_data.split("||")
    name = data[0]
    id = data[1]

    return name, id
  end

# Convert object into semi-structured data to be stored in Solr
  def to_solr_data
    "#{name}||#{id}".force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8).unicode_normalize(:nfkc)
  end

  def to_param
    param_name = name.gsub("-", "_")
    param_name.gsub!(/[^A-Za-z0-9_]/, "")
    "#{id}-#{param_name}"
  end

  #return what looks to be the last name in this name string
  def last_name
    self.name.split(',').first
  end

  def update_machine_name
    self.machine_name = make_machine_name(self.name) if self.name_changed?
  end
  
  # for encoding issue with SOLR
  def name=(aname)
    write_attribute(:name, aname.force_encoding('UTF-8').encode('UTF-8')).unicode_normalize(:nfkc)
  end   
   
end