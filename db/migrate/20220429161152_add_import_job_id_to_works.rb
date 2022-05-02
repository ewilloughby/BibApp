class AddImportJobIdToWorks < ActiveRecord::Migration[6.0]
  def change
    add_column :works, :import_job_id, :integer
  end
end
