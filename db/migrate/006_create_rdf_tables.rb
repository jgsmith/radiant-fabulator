# this is based on the pgsql schema in perl's RDF::Core
#
class CreateRdfTables < ActiveRecord::Migration
  def self.up
    create_table :rdf_namespaces do |t|
      t.string :namespace
    end

    add_index :rdf_namespaces, :namespace, :unique => true

    create_table :rdf_resources do |t|
      t.references :rdf_namespace
      t.string  :local_name
    end

    add_index :rdf_resources, [ :rdf_namespace_id, :local_name ], :unique => true

    create_table :rdf_models do |t|
      t.string :name, :null => false
      t.text   :description
      t.integer :lock_version, :default => 0
      t.integer :rdf_resources_count, :default => 0
      t.references :updated_by
      t.references :created_by
      t.timestamps
    end

    add_index :rdf_models, :name, :unique => true

    create_table :rdf_types do |t|
      t.string :name, :null => false
    end

    add_index :rdf_types, :name, :unique => true

    create_table :rdf_languages do |t|
      t.string :name, :null => false
    end

    add_index :rdf_languages, :name, :unique => true

    create_table :rdf_statements do |t|
      t.references :rdf_model, :null => false
      t.references :subject, :null => false
      t.references :predicate, :null => false
      t.references :object, :polymorphic => { :default => 'RdfResource' }, :null => false
    end

    create_table :rdf_literals do |t|
      t.references :rdf_type
      t.references :rdf_language
      t.text       :object_lit
    end

    add_index :rdf_statements, :rdf_model_id
    add_index :rdf_statements, [ :rdf_model_id, :subject_id ]
    add_index :rdf_statements, [ :rdf_model_id, :predicate_id ]
    add_index :rdf_statements, [ :rdf_model_id, :object_id ]
    add_index :rdf_statements, [ :rdf_model_id, :object_type, :object_id ]
    add_index :rdf_statements, [ :rdf_model_id, :subject_id, :predicate_id ]
    #add_index :rdf_statements, [ :rdf_model_id, :subject_id, :object_id ]
    add_index :rdf_statements, [ :rdf_model_id, :subject_id, :object_type, :object_id ]
    add_index :rdf_statements, [ :rdf_model_id, :predicate_id, :object_type, :object_id ]
    #add_index :rdf_statements, [ :rdf_model_id, :predicate_id, :object_lit ]
    add_index :rdf_statements, [ :rdf_model_id, :subject_id, :predicate_id, :object_type, :object_id ]
    #add_index :rdf_statements, [ :rdf_model_id, :subject_id, :predicate_id, :object_lit ]
  end

  def self.down
    remove_table :rdf_statements
    remove_table :rdf_literals
    remove_table :rdf_languages
    remove_table :rdf_types
    remove_table :rdf_models
    remove_table :rdf_resources
    remove_table :rdf_namespaces
  end
end
