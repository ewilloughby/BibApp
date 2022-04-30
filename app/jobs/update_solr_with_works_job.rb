# not being called
class UpdateSolrWithWorksJob < ApplicationJob
  queue_as :update_solr_with_works
  
  rescue_from(ActiveRecord::RecordNotFound) do |exception|
    # Do something with the exception
    Rails.logger.debug("\n\n============ IN ACTIVE_JOB -- UpdateSolrWithWorksJob: rescue_from =====\n")
    Rails.logger.debug( exception.to_s )
    #Delayed::Worker.logger.debug("\n\n============ IN ACTIVE_JOB -- WorkJob: rescue_from =====\n")
    #Delayed::Worker.logger.debug( exception.to_s )
  end
  
  #before_enqueue do |job|
  #end
  
  #around_enqueue do |job, block|
  #  
  #  logger.debug("\n\n============ IN ACTIVE_JOB -- UpdateSolrWithWorksJob: around_enqueue BEFORE =====\n")
  #  jid = job.instance_values['arguments'][0].id
  #  jtype = job.instance_values['arguments'][0].type
  #  
  #  block.call
  #  
  #  logger.debug("\n\n============ IN ACTIVE_JOB -- UpdateSolrWithWorksJob: around_enqueue AFTER =====\n")
  #  
  #end

  #before_perform do |job, block|
  #  
  #  logger.debug("\n\n============ IN ACTIVE_JOB -- WorkJob: before_perform =====\n")
  #  logger.debug(job.inspect)
  #  
  #  # Do something before perform
  #  block.call
  #end
  

  #around_perform do |job, block|
  #  # Do something before perform
  #  block.call
  #  # Do something after perform
  #end
  

  def perform(*args)
    
    Rails.logger.debug("\n\n============ IN ACTIVE_JOB -- UpdateSolrWithWorksJob: perform =====\n")
    Rails.logger.debug(" #{args.inspect} \n=====\n\n")
    # GLOBAL ID is included, or used by ActiveJob 
    
    # need to call .update_solr on the object 
    # type is one of Work types, eg. JournalArticle, etc.
    wobj = args[0]
    if wobj.respond_to?(:update_solr) && Work.exists?(wobj.id)
      wobj.update_solr 
    else
      Rails.logger.debug("  work.respond_to? FAILS OR WORK does not exist \n")
    end
    
  end
end
