class CreateFabulatorDatabasesTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_databases do |t|
      t.string :name, :null => false
      t.text   :description
      t.integer :lock_version, :default => 0
      t.string  :filename
      t.references :updated_by
      t.references :created_by
      t.timestamps
    end
  end

  def self.down
    drop_table :fabulator_databases
  end
end

