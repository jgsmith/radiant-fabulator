class CreateFabulatorLibrariesTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_libraries do |t|
      t.string :name, :null => false
      t.integer :lock_version, :default => 0
      t.text   :xml
      t.text   :compiled_xml
      t.references :updated_by
      t.references :created_by
      t.timestamps
    end
  end

  def self.down
    drop_table :fabulator_libraries
  end
end
