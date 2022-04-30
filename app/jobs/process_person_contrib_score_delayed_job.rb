#class ProcessPersonContribScoreDelayedJob < Struct.new(:person_id)
#  
#  def queue_name
#    "person_contributor_score"
#  end
#  
#  def enqueue(job)
#    
#    Rails.logger.debug("\n\n ========== ENQUEUEING PERSON_UPDATE_SOLR: #{person_id} =======\n")
#      
#    # can also change priority, DO I WANT WORKS LAST IN QUEUE
#    job.priority = 10  # lower the number the higher the priority, 0 being the highest priority
#    job.delayed_reference_id   = person_id
#    job.delayed_reference_type = 'Person'
#    job.save!
#    
#  end
#  
#  def perform
#    if Person.exists?(person_id)
#      
#      Person.find(person_id).recalculate_unverified_contributorship_score 
#      
#    else
#      # not expecting errors so let's see
#      Rails.logger.info("\n\n ========== JOB_FAILS_PERSON with ID: #{person_id} does not exist \n")
#      raise StandardError.new("Person for SOLR processing was not found. Id: #{person_id}") 
#    end
#    
#  end
#  
#  # just temporary for testing, since cannot save completed, successful jobs
#  def success(job)
#    idqueue = "#{job.id} #{job.queue}"
#    ref = "#{job.delayed_reference_id}::#{job.delayed_reference_type}"
#    Rails.logger.debug("\n\n ========== SUCCESSFUL_ASYNC_JOB PERSON: #{idqueue} - #{ref} ===========\n")
#  end
#  
#end
