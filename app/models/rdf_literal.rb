class RdfLiteral < ActiveRecord::Base
  has_many :rdf_statements, :as => :object

     # t.references :rdf_type
     # t.references :rdf_language
     # t.text       :object_lit

  def self.build(str,l=nil,t=nil, base=nil)
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
