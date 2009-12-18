class RdfLiteral < ActiveRecord::Base
  has_many :rdf_statements, :as => :object
  belongs_to :rdf_type, :class_name => 'RdfResource'
  belongs_to :rdf_language

     # t.references :rdf_type
     # t.references :rdf_language
     # t.text       :object_lit

  # eventually need to support language and type notation
  def to_s
    self.object_lit
  end

  def self.build(str,l=nil,t=nil, base=nil)
    if t.is_a?(String)
      t = RdfResource.from_uri(t)
    end

    if l.nil?
      if t.nil?
        lts = self.find(:all, :conditions => [ 'object_lit = ?', str ])
      else
        lts = t.rdf_literals.find(:all, :conditions => [ 'object_lit = ?', str ])
      end
    else
      if t.nil?
        lts = l.rdf_literals.find(:all, :conditions => [ 'object_lit = ?', str ])
      else
        lts = l.rdf_literals.find(:all, :conditions => [ 'rdf_type_id = ? AND object_lit = ?', t.id, str ])
      end
    end

    if lts.empty?
      lts << self.new({:object_lit => str, :rdf_type => t, :rdf_language => l})
    end
    lts.first
  end

  # we need optional support for spatial stuff
  def bnode?
    false
  end

  def literal?
    true
  end
end
