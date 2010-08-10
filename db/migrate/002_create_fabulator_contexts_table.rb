class CreateFabulatorContextsTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_contexts do |t|
      t.string     :session, :null => false
      t.references :page, :null => false
      t.references :user
      t.text       :context
      t.integer :lock_version, :default => 0
    end

    add_index :fabulator_contexts, [ :session, :page_id, :user_id ], :unique => true
  end

  def self.down
    drop_table :fabulator_contexts
  end
end
