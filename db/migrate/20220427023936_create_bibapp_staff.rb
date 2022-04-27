class CreateBibappStaff < ActiveRecord::Migration[6.0]
  def up
    create_table :bibapp_staff do |t|
      #t.integer :user_id
      t.string :login, limit: 12
      t.string :role, limit: 10
      t.string :first_name, limit: 15
      t.boolean :enabled, default: false
    end
    add_index :bibapp_staff, :login, unique: true
    add_reference :bibapp_staff, :user
  end
  def down
    drop_table :bibapp_staff
  end
end
