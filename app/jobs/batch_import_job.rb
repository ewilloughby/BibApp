class BatchImportJob < ApplicationJob
  queue_as :batch_import
  
  #before_enqueue do |job|
    # job here is nothing more than the import model, cannot access DJ model
  #end

  def perform(*args)
    # as called from models/import will know what to do
    obj = args[0]
    obj.batch_import
  end
end
