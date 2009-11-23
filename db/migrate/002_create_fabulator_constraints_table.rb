class CreateFabulatorConstraintsTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_constraints do |t|
      t.string :name, :null => false
      t.text   :description
      t.text   :lua_fn, :null => false, :default => ''
      t.integer :lock_version, :default => 0
      t.references :updated_by
      t.references :created_by
      t.timestamps
    end
  end

  def self.down
    drop_table :fabulator_constraints
  end
end
