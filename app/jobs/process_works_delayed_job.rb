class ProcessWorksDelayedJob < Struct.new(:work_id, :wtype)
  
  def queue_name
    "work_update_solr"
  end
  
  def enqueue(job)
    
    Rails.logger.debug("\n\n ========== ENQUEUEING WORK_UPDATE_SOLR: #{work_id} =======\n")
      
    # can also change priority, DO I WANT WORKS LAST IN QUEUE
    job.priority = 5  # lower the number the higher the priority, 0 being the highest priority
    job.delayed_reference_id   = work_id
    job.delayed_reference_type = wtype
    job.save!
    
  end
  
  def perform
    
    # sometimes deleted, or type changed before a job is run
    if Work.where(id: work_id, type: wtype).exists?
      
      Work.find(work_id).update_solr
      
    else
      # do I want to throw an error or just silently ignore a type that has changed or is deleted - IGNORE
      Rails.logger.info("\n\n ========== JOB_FAILS_FOR_WORK with ID: #{work_id} and TYPE: #{wtype} does not exist \n")
      #raise StandardError.new("Work for SOLR processing was not found. Type: #{wtype}, id: #{work_id}") 
    end
    
  end
  
  # just temporary for testing, since cannot save completed, successful jobs
  def success(job)
    idqueue = "#{job.id} #{job.queue}"
    ref = "#{job.delayed_reference_id}::#{job.delayed_reference_type}"
    Rails.logger.debug("\n\n ========== SUCCESSFUL_ASYNC_JOB WORK: #{idqueue} - #{ref} ===========\n")
  end
  
end
