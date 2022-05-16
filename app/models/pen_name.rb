# PenNames provide the logic for creating and destroying Contributorships
#   see the PenNameObserver for how these Contributorships are created/destroyed
class PenName < ActiveRecord::Base
  belongs_to :name_string
  belongs_to :person
  has_many :contributorships, :dependent => :destroy
  has_many :works, :through => :contributorships

  validates_presence_of :name_string_id, :person_id

  after_save :set_contributorships
  after_save :index_works
  before_destroy :index_works

  scope :for_name_string, lambda { |name_string_id| where(:name_string_id => name_string_id) }

  def set_contributorships
    logger.debug("\n\n ========== SET CONTRIBUTORSHIPS in PenName ========== \n\n")
    self.name_string.work_name_strings.each do |wns|
      #only create Contributorship for "accepted" works
      
      logger.debug(wns.inspect)
      
      if wns.work and wns.work.accepted?
        #self.contributorships.find_or_create_by_work_id_and_person_id_and_role(wns.work.id, self.person_id, wns.role)
        self.contributorships.find_or_create_by(work_id: wns.work.id, person_id: self.person_id, role: wns.role)
      end
    end
  end

  def index_works
    logger.debug("\n\n ========== INDEX WORKS in PenName ========== \n\n")
    self.works.each { |w| w.set_for_index_and_save }
    Index.batch_index
  end

end
