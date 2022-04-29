# doesn't appear this is being called
=begin
class PersonContributorScoreJob < ActiveJob::Base
  queue_as :person_contributor_score
  
  #before_enqueue do |job|
  #   # Do something with the job instance
  #end 
  
  around_perform do |job, block|
    
    # Do something before perform
    Rails.logger.debug("\n\n============= BEFORE_PERFORM:person_contributor_score: #{job.inspect} ========\n")
    Rails.logger.debug("#{block.inspect} ========\n")
    
    block.call
    
    # Do something after perform
    
    Rails.logger.debug("\n\n============= AFTER_PERFORM:person_contributor_score: #{job.inspect} ========\n")
    Rails.logger.debug("#{block.inspect} ========\n")
    
    
  end
  

  def perform(*args)
    
    Rails.logger.debug("\n\n============= QUEUE:person_contributor_score: #{args[0]} ========\n")
    
    obj_id = args[0]
    if Person.exists?(obj_id)
      Person.find(obj_id).recalculate_unverified_contributorship_score 
    end
    
  end
end
=end