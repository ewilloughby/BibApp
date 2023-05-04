class PersonScoringHashUpdateJob < ApplicationJob
end
# dont believe Synapse uses this, or only rarely
# it appears to be only for person imports, (not sure if MSK batch falls under this)
# called from Imports.process_accepted_import

# it does not get called from Scopus batch jobs
=begin
class PersonScoringHashUpdateJob < ActiveJob::Base
  queue_as :person_scoring_hash_update
  
  #before_enqueue do |job|
  #   # Do something with the job instance
  #end 
  
  def perform(*args)
    
    Rails.logger.debug("\n\n============= QUEUE:person_scoring_hash_update: #{args[0]} ========\n")

    obj_id = args[0]
    if Person.exists?(obj_id)
      Person.find(obj_id).update_scoring_hash
    end

  end
end
=end