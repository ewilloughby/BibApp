class DestroyWorkDelayedJob < Struct.new(:work_id, :wtype)
  
  def queue_name
    "work_destroy_queue"
  end
  
  
  def enqueue(job)
    job.priority = 10  # lower the number the higher the priority, 0 being the highest
    job.delayed_reference_id   = work_id
    job.delayed_reference_type = wtype
    job.save!
  end
  
  
  def perform
    
    if Delayed::Job.where(delayed_reference_id: work_id, delayed_reference_type: wtype).exists?
      Work.find(work_id).destroy
    else
      Rails.logger.debug("\n\n ========== DJ_FAILS_FOR_WORK with ID: #{work_id} does not exist \n")
      raise StandardError.new("Work to destroy was not found. Type: #{wtype}, id: #{work_id}") 
    end
    
  end
  
end
