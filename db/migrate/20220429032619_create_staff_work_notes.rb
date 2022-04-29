class CreateStaffWorkNotes < ActiveRecord::Migration[6.0]
  def change
    create_table :staff_work_notes do |t|
      t.integer :work_id
      t.text :note
    end
  end
end
