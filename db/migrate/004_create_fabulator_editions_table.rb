class CreateFabulatorEditionsTable < ActiveRecord::Migration
  def self.up
    create_table :fabulator_editions do |t|
      t.string :name, :null => false
      t.string :description
      t.integer :lock_version, :default => 0
      t.references :updated_by
      t.references :created_by
      t.timestamps
    end
  end

  def self.down
    drop_table :fabulator_editions
  end
end