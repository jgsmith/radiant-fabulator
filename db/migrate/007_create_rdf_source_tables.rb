class CreateRdfSourceTables < ActiveRecord::Migration
  def self.up
    create_table :rdf_user_assertions do |t|
      t.references :user, :null => false
      t.references :rdf_statement, :null => false
      t.timestamps
    end

    create_table :rdf_source_assertions do |t|
      t.references :rdf_resources, :null => false
      t.references :rdf_statement, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :rdf_resource_assertions
    drop_table :rdf_user_assertions
  end
end
