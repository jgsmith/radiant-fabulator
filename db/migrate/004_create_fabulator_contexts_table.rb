class CreateFabulatorContextsTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_contexts do |t|
      t.string     :session, :null => false
      t.references :page, :null => false
      t.text       :context
      t.integer :lock_version, :default => 0
    end
  end

  def self.down
    drop_table :fabulator_contexts
  end
end
