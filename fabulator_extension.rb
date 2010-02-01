require "rexml/document"
require 'xml/xslt'
require 'rdf/redland/parser'
require 'xml/libxml'

require_dependency "#{File.expand_path(File.dirname(__FILE__))}/lib/fabulator" #/state_machine"
require_dependency "#{File.expand_path(File.dirname(__FILE__))}/app/models/fabulator_page"

class FabulatorExtension < Radiant::Extension
  version "1.0"
  description "Applications as documents"
  url "http://github.com/jgsmith/radiant-fabulator"

  XML_PART_NAME = 'extended'

 define_routes do |map|
    map.namespace 'admin' do |admin|
      admin.namespace 'fabulator', :member => { :remove => :get } do |fab|
        fab.resources :filters
        fab.resources :constraints
        fab.resources :rdf_models
      end
    end
  end

  def activate
    FabulatorPage

    fab_tab = admin.nav_tab( :fabulator, "Fabulator" )
    fab_tab << admin.nav_item( :rdf_models, "RDF Models", "/admin/fabulator/rdf_models" )
    fab_tab << admin.nav_item( :filters, "Filters", "/admin/fabulator/filters" )
    fab_tab << admin.nav_item( :constraints, "Constraints", "/admin/fabulator/constraints" )
    admin.nav << fab_tab

   Radiant::AdminUI.class_eval do
      attr_accessor :filters
      alias_method :fabulator_filter, :filters
      attr_accessor :constraints
      alias_method :fabulator_constraint, :constraints
      attr_accessor :databases
      alias_method :fabulator_databases, :databases
      alias_method :rdf_models, :databases
    end
    admin.filters = load_default_fabulator_filter_regions
    admin.constraints = load_default_fabulator_filter_regions
    admin.databases = load_default_fabulator_database_regions
  end

  def deactivate
  end

  def load_default_fabulator_filter_regions
    returning OpenStruct.new do |filter|
      filter.edit = Radiant::AdminUI::RegionSet.new do |edit|
        edit.main.concat %w{edit_header edit_form}
        edit.form.concat %w{edit_title edit_description edit_fn}
        edit.form_bottom.concat %w{edit_buttons edit_timestamp}
      end
      filter.index = Radiant::AdminUI::RegionSet.new do |index|
        index.top.concat %w{help_text}   
        index.thead.concat %w{title_header modify_header}
        index.tbody.concat %w{title_cell modify_cell}
        index.bottom.concat %w{new_button}
      end
      filter.new = filter.edit
    end
  end
  def load_default_fabulator_database_regions
    returning OpenStruct.new do |filter|
      filter.edit = Radiant::AdminUI::RegionSet.new do |edit|
        edit.main.concat %w{edit_header edit_form}
        edit.form.concat %w{edit_title edit_namespace edit_description}
        edit.form_bottom.concat %w{edit_buttons edit_timestamp}
      end
      filter.index = Radiant::AdminUI::RegionSet.new do |index|
        index.top.concat %w{help_text}   
        index.thead.concat %w{title_header namespace_header size_header modify_header}
        index.tbody.concat %w{title_cell namespace_cell size_cell modify_cell}
        index.bottom.concat %w{new_button}
      end
      filter.new = filter.edit
    end
  end
end
