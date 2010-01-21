require 'rgl/adjacency'
require 'rgl/topsort'

class RdfModel < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'
  belongs_to :rdf_namespace

  has_many :rdf_statements

  def size
    self.rdf_statements.size
  end

  def namespace
    self.rdf_namespace.namespace rescue ''
  end

  def namespace=(n)
    ns = RdfNamespace.first(:conditions => [ 'namespace = ?', n ])
    if ns.nil?
      ns = RdfNamespace.create({ :namespace => n })
    end
    self.update_attribute(:rdf_namespace_id, ns.id)
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

  def create_resource
    RdfResource.create_resource(self.rdf_namespace)
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
          return self.rdf_statements.find(:all, :conditions => [ 'subject_id = ? AND predicate_id = ?', s.id, p.id ])
        else
          # all <s,p,o> with this s,p,o
          return [] if o.new_record?
          return RdfStatement.find(:all,
            :conditions => [
              %{subject_id = ? AND predicate_id = ? AND object_id = ? AND
                rdf_model_id = ? AND object_type = ?}, s.id, p.id, o.id,
                self.id, o.class.to_s ]
          )
        end
      end
    end
  end

  def count_statements(s=nil,p=nil,o=nil)
    if s.nil?
      if p.nil?
        if o.nil?
          # a sequence of all statements in this model
          return self.rdf_statements.count
        else
          # all <s,p> with this o
          return 0 if o.new_record?
          return o.rdf_statements.count(:conditions => [ 'rdf_model_id = ?', self.id ])
        end
      else
        return 0 if p.new_record?
        if o.nil?
          # all <s,o> with this p
          return self.rdf_statements.count(:conditions => [ 'predicate_id = ?', p.id ])
        else
          # all <s> with this p and o
          return o.rdf_statements.count(:conditions => [ 'predicate_id = ? AND rdf_model_id = ?', p.id, self.id ])
        end
      end
    else
      return 0 if s.new_record?
      if p.nil?
        if o.nil?
          # all <p,o> with this s
          return s.rdf_statements.count(:conditions => [ 'rdf_model_id = ?', self.id])
        else
          # all <p> with this s and o
          return 0 if o.new_record?
          return o.rdf_statements.count(:conditions => [ 'rdf_model_id = ? AND subject_id = ?', self.id, s.id ])
        end
      else
        return 0 if p.new_record?
        if o.nil?
          # all <o> with this s and p
          return self.rdf_statements.count(:conditions => [ 'statement_id = ? AND predicate_id = ?', s.id, p.id ])
        else
          # all <s,p,o> with this s,p,o
          return 0 if o.new_record?
          return RdfStatement.count(
            :conditions => [
              %{subject_id = ? AND predicate_id = ? AND object_id = ? AND
                rdf_model_id = ? AND object_type = ?}, s.id, p.id, o.id,
                self.id, o.class.to_s ]
          )
        end
      end
    end
  end

  def add_statement(s,p,o)
    return if s.nil? || p.nil? || o.nil?
    st = self.find_statements(s,p,o)
    if st.empty?
      s.save! if s.new_record?
      p.save! if p.new_record?
      o.save! if o.new_record?
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
          return if o.bnode? && self.count_statements(o,nil,nil) > 0

          o.rdf_statements.delete(:conditions => [ 'rdf_model_id = ?' , self.id ])
        end
      else
        return if p.new_record?
        if o.nil?
          # all <s,o> with this p  
          self.rdf_statements.delete(:conditions => [ 'predicate_id = ?', p.id ])
        else
          # all <s> with this p and o
          return if o.new_record?
          return if o.bnode? && self.count_statements(o,nil,nil) > 0

          return o.rdf_statements.delete(:conditions => [ 'predicate_id = ?  AND rdf_model_id = ?', p.id, self.id ])
        end
      end
    else
      return if s.new_record?
      if p.nil?
        if o.nil?
          # all <p,o> with this s  
          s.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ?', self.id]).each do |ob|
            ob.destroy
          end
        else
          # all <p> with this s and o
          return if o.new_record?
          return if o.bnode? && self.count_statements(o,nil,nil) > 0

          o.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ? AND subject_id = ?', self.id, s.id ]).each do |ob|
            ob.destroy
          end
        end
      else
        return if p.new_record?
        if o.nil?
          # all <o> with this s and p
          self.rdf_statements.find(:all, :conditions => [ 'subject_id = ? AND predicate_id = ?', s.id, p.id ]).each do |ob|
            ob.destroy
          end
        else
          # all <s,p,o> with this s,p,o
          return if o.new_record?
          return if o.bnode? && self.count_statements(o,nil,nil) > 0

          Rails.logger.info("delete <#{s},#{p},#{o}>")
          o.rdf_statements.find(:all, :conditions => [ 'rdf_model_id = ? AND subject_id = ? AND predicate_id = ?', self.id, s.id, p.id ]).each do |ob|
            ob.destroy
          end
        end
      end
    end
  end

  def self.build_query(rdf)
    rdf_doc = LibXML::XML::Document.new
    rdf_doc.root = rdf_doc.import(rdf)
    return self.bgp_to_sql(self.rdf_to_bgp(rdf_doc.to_s))
  end

  def self.build_arcs(rdf)
    rdf_doc = LibXML::XML::Document.new
    rdf_doc.root = rdf_doc.import(rdf)
    return self.bgp_to_arcs(self.rdf_to_bgp(rdf_doc.to_s))
  end

  def self.sanitize_where(c)
    self.sanitize_sql_for_conditions(c)
  end

protected

  def self.rdf_to_bgp(rdf)

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
  # This takes the list of triples and produces a sequence of arcs that
  # should be (or not) present in the database
  def self.bgp_to_arcs(bgp)
    # we need to rank terms in order of dependence
    # subjects must be defined before predicates/objects
    # we'll have data pulled from the context as well as variables filled
    # in as we add triples (especially for intermittent blank nodes)
    joins = [ ]
    vars = self.vars_from_bgp(bgp)

    constants = [ ]
    s_arcs = { }
    o_arcs = { }
    p_arcs = { }
    bnode_arcs = { }
    arcs = { }
    bgp[:terms].each do |t|
      spo = 0
      spo = spo | 1 if t[0] =~ /^\?/
      spo = spo | 2 if t[1] =~ /^\?/
      spo = spo | 2 if t[1] =~ %r{^http://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)$}
      spo = spo | 4 if t[2].is_a?(Array) && t[2][0] =~ /^\?/
      spo = spo | 4 if !t[2].is_a?(Array) && t[2] =~ /^\?/
      spo = spo | 16 if t[0] =~ /^\{/
      spo = spo | 32 if t[1] =~ /^\{/
      spo = spo | 64 if t[2].is_a?(Array) && t[2][0] =~ /^\{/
      spo = spo | 64 if !t[2].is_a?(Array) && t[2] =~ /^\{/
      puts "#{spo}: <#{t.join("><")}>"
      arcs[t[0]] = [] if arcs[t[0]].nil?
      arcs[t[0]] << [spo, t[1], t[2]]
    end
    # we want the constant triplets first
    vars[:graph] = arcs # .collect {|a| a.sort_by{|k| k[0]} }

    # now figure out dependency graph -- doesn't change with data
    dg = RGL::DirectedAdjacencyGraph[]
    arcs.each_pair do |v,es|
      next unless v =~ /\?/
      es.each do |e|
        if e[2].is_a?(Array)
          dg.add_edge v, e[2][0] if e[2][0] =~ /^\?/
        else
          dg.add_edge v, e[2] if e[2] =~ /^\?/
        end
      end
    end
    vars[:sorted_vars] = dg.topsort_iterator.to_a
    #varcs = [ ]
    #vars[:sorted_vars].each do |u|
    #  next if u =~ /^\?_/
    #  varcs = varcs + self.build_arcs_from_graph(dg,u)
    #end
    #varcs2 = [ ]
    #varcs.each do |v|
    #  Rails.logger.info("v: #{v}")
    #  self.varc_flattened(v) do |vv|
    #    varcs2 << [ v[0][0] ] + vv
    #  end
    #end
    #vars[:arcs] = varcs2

    # now to create SELECT to test each arc for existance
    # and return the blank node identifiers if it does
    # will need to check for Bag/Seq predicates
    
    return vars

    if false
      case spo
        when 0:
          # make sure triple is in play
          constants << [spo] + t
        when 1:
          if t[0] =~ /\?_/
            bnode_arcs[t[0]] = [ ] if bnode_arcs[t[0]].nil?
            bnode_arcs[t[0]] << [spo] + t
          else
            s_arcs[t[0]] = [ ] if s_arcs[t[0]].nil?
            s_arcs[t[0]] << [spo] + t
          end
        when 2:
          if t[1] =~ /\?_/
            bnode_arcs[t[1]] = [ ] if bnode_arcs[t[1]].nil?
            bnode_arcs[t[1]] << [spo] + t
          else
            p_arcs[t[1]] = [ ] if p_arcs[t[1]].nil?
            p_arcs[t[1]] << [spo] + t
          end
        when 3:
          if t[0] =~ /\?_/
            bnode_arcs[t[0]] = [ ] if bnode_arcs[t[0]].nil?
            if t[1] =~ %r{^http://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)$}
              bnode_arcs[t[0]] << [ spo, t[0], t[0]+'_'+$1, t[2] ]
            else
              bnode_arcs[t[0]] << [spo] + t
            end
          else
          end
        when 4:
          if t[2] =~ /\?_/
            bnode_arcs[t[2]] = [ ] if bnode_arcs[t[2]].nil?
            bnode_arcs[t[2]] << [spo] + t
          else
            o_arcs[t[2]] = [ ] if o_arcs[t[2]].nil?
            o_arcs[t[2]] << [spo] + t
          end
        when 5:
          if t[2] =~ /\?_/
            bnode_arcs[t[2]] = [ ] if bnode_arcs[t[2]].nil?
            bnode_arcs[t[2]] << [spo] + t
          elsif t[0] =~ /\?_/
            bnode_arcs[t[0]] = [ ] if bnode_arcs[t[0]].nil?
            bnode_arcs[t[0]] << [spo] + t
          else
            o_arcs[t[2]] = [ ] if o_arcs[t[2]].nil?
            o_arcs[t[2]] << [spo] + t
          end
      end
    end
    return { :arcs => constants + s_arcs.values + o_arcs.values + p_arcs.values + bnode_arcs.values, :vars => vars, :froms => froms }
  end

  def self.build_arcs_from_graph(dg,u)
    as = [ ]
    dg.each_adjacent(u) do |v|
      if v =~ /\?_/
        as << [ [ u, v ] ] + self.build_arcs_from_graph(dg,v)
      else
        as << [ [ u, v ] ]
      end
    end
    as
  end

  def self.varc_flattened(v,&block)
    if v.is_a?(Array)
      if v.size == 1
        yield [ v[0][1] ]
      else
        v[1].each do |vp|
          if vp.is_a?(Array) && vp[0].is_a?(Array)
            self.varc_flattened(vp) do |vv|
              yield [ v[0][1] ] + vv
            end
          else
            yield [ v[0][1], vp[1] ]
          end
        end
      end
    else
      yield [ v ]
    end
  end
        

  def self.vars_from_bgp(bgp)
    froms = [ ]
    vars = { }
    bgp[:terms].size.times do |i|
      froms << "rdf_statements rs_#{i}"
      if bgp[:terms][i][0] =~ /^\?(.*)$/
        vars[$1] = [ :subject, "rs_#{i}" ]
      elsif bgp[:terms][i][0] =~ /^(\{.*\})$/
        vars[$1] = [ :subject, "rs_#{i}" ]
      end
      if bgp[:terms][i][1] =~ /^\?(.*)$/
        vars[$1] = [ :predicate, "rs_#{i}" ]
      elsif bgp[:terms][i][1] =~ /^(\{.*\})$/
        vars[$1] = [ :predicate, "rs_#{i}" ]
      elsif bgp[:terms][i][1] =~ %r{^http://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)$}
        vars[bgp[:terms][i][0]+'_'+$1] = [ :predicate, bgp[:terms][i][0]+'_'+$1 ]
      end
      if bgp[:terms][i][2].is_a?(Array)
        if bgp[:terms][i][2][0] =~ /^\?(.*)$/
          vars[$1] = [ :object, "rs_#{i}" ]
        elsif bgp[:terms][i][2][0] =~ /^(\{.*\})$/
          vars[$1] = [ :object, "rs_#{i}" ]
        end
      else
        if bgp[:terms][i][2] =~ /^\?(.*)$/
          vars[$1] = [ :object, "rs_#{i}" ]
        elsif bgp[:terms][i][2] =~ /^(\{.*\})$/
          vars[$1] = [ :object, "rs_#{i}" ]
        end
      end
    end
    return { :froms => froms, :vars => vars }
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
    expr_parser = Fabulator::XSM::ExpressionParser.new
    from = []
    joins = []
    vars = self.vars_from_bgp(bgp)
    sql_args[:from] = vars[:froms].join(", ")
    vars = vars[:vars]
    # Build the select statement
    select = []
    vars.each_pair do |v,i|
      next if v =~ /^[{_]/
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
      elsif bgp[:terms][i][0] =~ /^\{(.*)\}$/
        expr = $1
        if this_table != vars["{#{expr}}"][1] && vars["{#{expr}}"][0] == :subject
          where << %{#{this_table}.subject_id = #{vars["{#{expr}}"][1]}.subject_id}
        else
          where << %{#{this_table}.subject_id in (%s)}
          where_params << [ :resource, expr_parser.parse(expr) ]
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
        elsif bgp[:terms][i][2][0] =~ /^\{(.*)\}$/
          expr = $1
          if this_table != vars["{#{expr}}"][1] && vars["{#{expr}}"][0] == :object
            where << %{#{this_table}.object_type = #{vars["{#{expr}}"][1]}.object_type AND
                       #{this_table}.object_id = #{vars["{#{expr}}"][1]}.object_id}
          else
            where << %{
              (#{this_table}.object_id in (%s) AND #{this_table}.object_type = 'RdfLiteral') OR
              (#{this_table}.object_id in (%s) AND #{this_table}.object_type = 'RdfResource')
            }
            where_params << [ :literal, expr_parser.parse(expr) ]
            where_params << [ :resource, expr_parser.parse(expr) ]
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
