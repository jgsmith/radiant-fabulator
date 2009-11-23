class RdfModel < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'

  has_many :rdf_statements

  def size
    self.rdf_statements.size
  end

  def namespaces
    RdfNamespace.find(:all,
      :joins => %{
        LEFT JOIN rdf_resources ON 
          rdf_resources.rdf_namespace_id = rdf_namespaces.id
        LEFT JOIN rdf_statements ON 
          ( rdf_statements.subject_id = rdf_resources.id
            OR rdf_statements.predicate_id = rdf_resources.id
            OR (rdf_statements.object_type = 'RdfResource' 
                AND rdf_statements.object_id = rdf_resources.id)
          )
      },
      :conditions => [ 'rdf_statements.rdf_model_id = ?', self.id ],
      :select => 'DISTINCT rdf_namespaces.*'
    )
  end

  def find_statements(s=nil,p=nil,o=nil)
    if s.nil?
      if p.nil?
        if o.nil?
          # a sequence of all statements in this model
          return self.rdf_statements
        else
          # all <s,p> with this o
          return [] if o.new_record?
          return o.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ?', self.id ])
        end
      else
        return [] if p.new_record?
        if o.nil?
          # all <s,o> with this p
          return self.rdf_statements.find(:all, :conditions => [ 'predicate_id = ?', p.id ])
        else
          # all <s> with this p and o
          return o.rdf_statements.find(:all, :conditions => [ 'predicate_id = ? AND rdf_model_id = ?', p.id, self.id ])
        end
      end
    else
      return [] if s.new_record?
      if p.nil?
        if o.nil?
          # all <p,o> with this s
          return s.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ?', self.id])
        else
          # all <p> with this s and o
          return [] if o.new_record?
          return o.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ? AND subject_id = ?', self.id, s.id ])
        end
      else
        return [] if p.new_record?
        if o.nil?
          # all <o> with this s and p
          return self.rdf_statements.find(:all, :conditions => [ 'statement_id = ? AND predicate_id = ?', s.id, p.id ])
        else
          # all <s,p,o> with this s,p,o
          return [] if o.new_record?
          return o.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ? AND statement_id = ? AND predicate_id = ?', self.id, s.id, p.id ])
        end
      end
    end
  end

  def add_statement(s,p,o)
    st = self.find_statements(s,p,o)
    if st.empty?
      self.rdf_statements.create({
        :subject => s,
        :predicate => p,
        :object => o
      });
    else
      st.first
    end
  end

  def remove_statement(s=nil, p=nil, o=nil)
    if s.nil?
      if p.nil?
        if o.nil?
          # a sequence of all statements in this model
          self.rdf_statements.clear
        else
          # all <s,p> with this o
          return if o.new_record?
          o.rdf_statements.delete(:conditions => [ 'rdf_model_id = ?' , self.id ])
        end
      else
        return if p.new_record?
        if o.nil?
          # all <s,o> with this p  
          self.rdf_statements.delete(:conditions => [ 'predicate_id = ?', p.id ])
        else
          # all <s> with this p and o
          return o.rdf_statements.delete(:conditions => [ 'predicate_id = ?  AND rdf_model_id = ?', p.id, self.id ])
        end
      end
    else
      return if s.new_record?
      if p.nil?
        if o.nil?
          # all <p,o> with this s  
          return s.rdf_statements.find(:conditions => [ 'rdf_model_id = ?', self.id])
        else
          # all <p> with this s and o
          return if o.new_record?
          o.rdf_statements.delete(:conditions => [ 'rdf_model_id = ? AND subject_id = ?', self.id, s.id ])
        end
      else
        return if p.new_record?
        if o.nil?
          # all <o> with this s and p
          self.rdf_statements.delete(:conditions => [ 'statement_id = ? AND predicate_id = ?', s.id, p.id ])
        else
          # all <s,p,o> with this s,p,o
          return if o.new_record?
          o.rdf_statements.delete(:conditions => [ 'rdf_model_id = ? AND statement_id = ? AND predicate_id = ?', self.id, s.id, p.id ])
        end
      end
    end
  end

  def self.build_query(rdf)
    rdf_doc = LibXML::XML::Document.new
    rdf_doc.root = rdf_doc.import(rdf)
    bgp = self.rdf_to_bgp(rdf_doc.to_s)
    sql = self.bgp_to_sql(bgp)
    return sql
  end

  def self.sanitize_where(c)
    Rails.logger.info(YAML::dump(c))
    Rails.logger.info(YAML::dump(c))
    self.sanitize_sql_for_conditions(c)
  end

protected

 #   <rdf:RDF>
 #     <City about="?url">
 #       <rdfs:label>?name</rdfs:label>
 #     </City>
 #   </rdf:RDF>
  def self.xml_to_ntriples(xml, base=nil, &blk)
    #parser = RdfModel::Parser.new
    #parser.parse(xml, base)
  end

    RDF_NS='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
    RDFS_NS='http://www.w3.org/2000/01/rdf-schema#'
    XML_NS='http://www.w3.org/XML/1998/namespace'

  def self.xml_to_ntriples_2(xml, base = nil, subj = nil, &blk)
    type_resource = RdfResource.from_uri(RDFS_NS + "type")
    b = xml.attributes.get_attribute_ns(XML_NS, 'base').value rescue nil
    base = b unless b.nil?
    if subj.nil?
      subj = xml.attributes.get_attribute_ns(RDF_NS,'about').value rescue nil
      subj = RdfResource.from_uri(subj, base)
    end
    parse_type = xml.attributes.get_attribute_ns(RDF_NS,'parseType').value rescue nil
    if xml.namespaces.namespace == RDF_NS && xml.name == 'Description'
      # type is RDFS_NS:type 
      t = xml.attributes.get_attribute_ns(RDFS_NS,'type') rescue nil
      if !t.nil?
        yield [ subj, type_resource, RdfResource.from_uri(t, base) ]
      end
      parse_type = 'Resource' if parse_type.nil?
    elsif xml.namespaces.namespace == RDF_NS && xml.name == 'Seq'
      parse_type = 'Seq' if parse_type.nil?
    else
      yield [ subj, type_resource, RdfResource.from_uri(xml.namespaces.namespace + xml.name, base) ]
      parse_type = 'Resource' if parse_type.nil?
    end
    parse_type = 'Resource' if parse_type.nil?
    case parse_type
      when 'Resource':
        xml.attributes.each do |attr|
          next if attr.namespace == RDF_NS && attr.name == 'about'
          next if attr.namespace == RDFS_NS && attr.name == 'type'
          next if attr.namespace == XML_NS
          pred = RdfResource.from_uri(attr.namespace + attr.name, base)
          obj = RdfLiteral.build(attr.value)
          yield [ subj, pred, obj ]
        end
        xml.each_element do |child|
          if child.empty?
            if r = child.attributes.get_attribute_ns(RDF_NS, 'resource')
              yield [ subj, RdfResource.from_uri(child.namespaces.namespace+child.name, base), RdfResource.from_uri(r, base) ]
            else
              yield [ subj, RdfResource.from_uri(child.namespaces.namespace+child.name, base), RdfLiteral.build('') ]
            end
          elsif child.children.select{|c| !c.text? && !c.cdata? && !c.comment? && !c.entity_ref?}.size == 0
            t = child.attributes.get_attribut_ns(RDFS_NS,'type') rescue nil
            l = child.lang rescue nil
            c = child.content
            yield [ subj, RdfResource.from_uri(child.namespaces.namespace+child.name, base), RdfLiteral.build(c, l, t, base) ]
          else
            # handle collections and bnodes
            # rdf:Seq, 
          end
        end
      when 'Collection':
    end
  end

  def self.rdf_to_bgp(rdf)

    Rails.logger.info("RDF: [#{rdf}]")

    #wheres = [ ]
    
    parser = Redland::Parser.new
    
    wheres = [ ]
    #selects = [ ]
    parser.parse_string_as_stream(rdf, ':') do |s|
      subj = s.subject
      pred = s.predicate   
      obj  = s.object

      w = [ ]
      if subj.blank?
        w[0] = '?_' + subj.blank_identifier
      else
        w[0] = subj.uri.to_s
      end
      if pred.blank?
        w[1] = '?_' + pred.blank_identifier
      else
        w[1] = pred.uri.to_s
      end
      if obj.blank?
        w[2] = '?_' + obj.blank_identifier
      elsif obj.literal?
        w[2] =  [ obj.value, obj.language ]
      else
        w[2] = obj.uri.to_s
      end
      wheres << w
    end
    return { :terms => wheres }
  end

  #
  # this is taken from http://www.cs.wayne.edu/~artem/main/research/TR-DB-052006-CLJF.pdf
  # the result is a hash of stuff for a RdfStatement.find(:all, ...) call
  # the :conditions array will need to be modified at query time to
  # reference actual resources/literals
  #
  # the result of this call can be saved at state machine compile time
  #

  def self.bgp_to_sql(bgp)
    sql_args = { }
    # Substitute each distinct blank node label in BGP with a unique variable
    # Assign each edge e in E a unique table alias t_e
    # Construct the FROM clause to contain all the table aliases
    from = []
    joins = []
    vars = { }
    bgp[:terms].size.times do |i|
      from << "rdf_statements rs_#{i}"
      if bgp[:terms][i][0] =~ /^\?(.*)$/
        vars[$1] = [ :subject, "rs_#{i}" ]
      end
      if bgp[:terms][i][1] =~ /^\?(.*)$/
        vars[$1] = [ :predicate, "rs_#{i}" ]
      end
      if bgp[:terms][i][2].is_a?(Array)
        if bgp[:terms][i][2][0] =~ /^\?(.*)$/
          vars[$1] = [ :object, "rs_#{i}" ]
        end
      else
        if bgp[:terms][i][2] =~ /^\?(.*)$/
          vars[$1] = [ :object, "rs_#{i}" ]
        end
      end
    end
    sql_args[:from] = from.join(", ")
    # Build the select statement
    select = []
    vars.each_pair do |v,i|
      next if v =~ /^_/
      if i[0] == :predicate
        select << "#{i[1]}.predicate_id AS #{v}_id"
      elsif i[0] == :object
        select << "#{i[1]}.object_type AS #{v}_type, #{i[1]}.object_id AS #{v}_id"
      else # i[0] == :subject
        select << "#{i[1]}.subject_id AS #{v}_id"
      end
    end
    sql_args[:select] = select.join(", ")

    where = [ ]
    where_params = [ ]
    bgp[:terms].size.times do |i|
      this_table = "rs_#{i}"
      if bgp[:terms][i][0] =~ /^\?(.*)$/
        s_var = $1
        if this_table != vars[s_var][1] && vars[s_var][0] == :subject
          where << %{#{this_table}.subject_id = #{vars[s_var][1]}.subject_id}
        end
      else
        where << %{#{this_table}.subject_id = %s}
        where_params << [ :resource, bgp[:terms][i][0] ]
      end
      if bgp[:terms][i][1] =~ /^\?(.*)$/
        p_var = $1
        if this_table != vars[p_var][1] && vars[p_var][0] == :predicate
          where << %{#{this_table}.predicate_id = #{vars[p_var][1]}.predicate_id}
        end
      elsif bgp[:terms][i][1] =~ /^http:\/\/www.w3.org\/1999\/02\/22-rdf-syntax-ns#_/
        rr_n = "rr_#{joins.size}"
        joins << %{LEFT JOIN rdf_resources #{rr_n} ON #{rr_n}.id = #{this_table}.predicate_id}
        where << %{#{rr_n}.rdf_namespace_id = %s AND #{rr_n}.local_name LIKE '_%%'}
        where_params << [ :namespace, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' ]
      else
        where << %{#{this_table}.predicate_id = %s}
        where_params << [ :resource, bgp[:terms][i][1] ]
      end
      if bgp[:terms][i][2].is_a?(Array)
        if bgp[:terms][i][2][0] =~ /^\?(.*)$/
          o_var = $1
          if this_table != vars[o_var][1] && vars[o_var][0] == :object
            where << %{
              #{this_table}.object_type = #{vars[o_var][1]}.object_type AND
              #{this_table}.object_id   = #{vars[o_var][1]}.object_id
            }
          elsif this_table != vars[o_var][1]
            where << %{
              #{this_table}.object_type = 'RdfResource' AND
              #{this_table}.object_id = #{vars[o_var][1]}.subject_id
            }
          end
        else
          where << %{#{this_table}.object_type = 'RdfLiteral' AND #{this_table}.object_id = %s}
          where_params << [ :literal, bgp[:terms][i][2] ] 
        end
      else
        if bgp[:terms][i][2] =~ /^\?(.*)$/
          o_var = $1
          if this_table != vars[o_var][1] && vars[o_var][0] == :object
            where << %{
              #{this_table}.object_type = #{vars[o_var][1]}.object_type AND
              #{this_table}.object_id   = #{vars[o_var][1]}.object_id
            }
          elsif this_table != vars[o_var][1]
            where << %{
              #{this_table}.object_type = 'RdfResource' AND
              #{this_table}.object_id = #{vars[o_var][1]}.subject_id
            }
          end
        else
          where << %{#{this_table}.object_type = 'RdfResource' AND #{this_table}.object_id = %s}
          where_params << [ :resource, bgp[:terms][i][2] ] 
        end
      end
    end
    bgp[:terms].size.times do |i|
      where << "rs_#{i}.rdf_model_id = %s"
      where_params << :model
    end
    sql_args[:simple_where] = where.join("\n    AND ")
    sql_args[:where_params] = where_params
    sql_args[:joins] = joins.join("\n")
   
    return sql_args
  end
end
