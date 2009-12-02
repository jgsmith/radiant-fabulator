require 'uuid'

class RdfResource < ActiveRecord::Base
  belongs_to :rdf_namespace
  validates_presence_of :local_name
  validates_uniqueness_of :local_name, :scope => 'rdf_namespace_id'

  has_many :as_subject, :class_name => 'RdfStatement', :foreign_key => 'subject_id'
  has_many :as_predicate, :class_name => 'RdfStatement', :foreign_key => 'predicate_id'
  has_many :as_object, :as => :object, :class_name => 'RdfStatement'

  def rdf_statements
    RdfStatement.find(:all, 
      :conditions => [ %{
        subject_id = ? 
        OR predicate_id = ? 
        OR (object_id = ? AND object_type = 'RdfStatement')
      }, self.id, self.id, self.id ],
      :select => 'DISTINCT *'
    )
  end

  def self.find_or_create(ns,ln)
    ns_obj = RdfNamespace.first(:conditions => [ 'namespace = ?', ns ])
    if ns_obj.nil?
      ns_obj = RdfNamespace.create(:namespace => ns)
    end
    return ns_obj[ln]
  end

  def self.from_uri(uri, base = nil)
    bits = uri.split('#',2)
    if bits.size == 2
      if ns = RdfNamespace.first(:conditions => [ 'namespace = ?', bits[0]+'#'])
        return ns[bits[1]]
      else
        ns = RdfNamespace.create(:namespace => bits[0]+'#')
        return ns[bits[1]]
      end
    end
    bits = uri.split("/")
    if bits.size > 1
      ln = bits.pop
      ns_s = bits.join("/")
      if ns = RdfNamespace.first(:conditions => [ 'namespace = ?', ns_s + '/'])
        return ns[ln]
      else
        ns = RdfNamespace.create(:namespace => ns_s + '/')
        return ns[ln]
      end
    else
      bits = uri.split(":")
      ln = bits.pop
      ns_s = bits.join(":")
      if ns = RdfNamespace.first(:conditions => [ 'namespace = ?', ns_s + ':'])
        return ns[ln]
      else
        ns = RdfNamespace.create(:namespace => ns_s + ':')
        return ns[ln]
      end
    end
  end

  def uri
    self.rdf_namespace.namespace + self.local_name
  end

  def self.create_resource(ns)
    @@uuid ||= UUID.new
    ns[@@uuid.generate(:compact)]
  end

  def self.create_bnode
    # use own NS and uuid for identifier
    @@uuid ||= UUID.new
    self.from_uri('_:' + @@uuid.generate(:compact))
  end

  def bnode?
    self.rdf_namespace.namespace == '_:'
  end

  def literal?
    false
  end
end
