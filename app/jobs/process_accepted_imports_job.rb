class ProcessAcceptedImportsJob < ApplicationJob
  queue_as :process_accepted_imports

  def perform(*args)
    Rails.logger.debug("\n\n============ PROCESS_ACCEPTED_IMPORT called ================\n")
    Rails.logger.debug(args.inspect)
    
    # as called from models/import will know what to do
    obj = args[0]
    obj.process_accepted_import
    
  end
end
