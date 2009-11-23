require 'rdf/redland'

class FabulatorDatabase < ActiveRecord::Base
  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  belongs_to :rdf_mode:wl

  # TODO: need to move file if we change the filename

  def dir
    RAILS_ROOT + '/rdf_databases'
  end

  def rdf_store
    @store ||= Redland::HashStore.new('bdb', self.filename, self.dir)
    @store
  end

  def rdf_model(dir = '.')
    @model ||= Redland::Model.new(self.rdf_store)
    @model
  end

  def query(q)
    parsed_q = Redland::Query.new(q)
    parsed_q.execute(self.rdf_model)
  end

  def add(s,p,o,c = nil)
    self.rdf_model.add(s,p,o,c)
  end

  def delete(s,p,o,c = nil)
    self.rdf_model.delete(s,p,o,c)
  end

  def find(s=nil,p=nil,o=nil,c=nil)
    self.rdf_model.find(s,p,o,c)
  end

  def include?(s,p,o)
    self.rdf_model.include?(s,p,o)
  end
end

