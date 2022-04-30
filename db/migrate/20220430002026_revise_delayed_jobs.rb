class ReviseDelayedJobs < ActiveRecord::Migration[6.0]
  def change
    add_column :delayed_jobs, :delayed_reference_id, :integer
    add_column :delayed_jobs, :delayed_reference_type, :string
    
    #add_index :delayed_jobs, [:queue], :name => 'delayed_jobs_queue'
    add_index :delayed_jobs, [:delayed_reference_id],   :name => 'delayed_jobs_delayed_reference_id'
    add_index :delayed_jobs, [:delayed_reference_type], :name => 'delayed_jobs_delayed_reference_type'
  end
end
