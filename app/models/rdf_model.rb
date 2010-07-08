require 'rgl/adjacency'
require 'rgl/topsort'

class RdfModel < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name

  belongs_to :updated_by, :class_name => 'User'
  belongs_to :created_by, :class_name => 'User'
  belongs_to :rdf_namespace

  has_many :rdf_statements

  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'

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

          #Rails.logger.info("delete <#{s},#{p},#{o}>")
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

      Rails.logger.info("Parsed: <#{subj}|#{pred}|#{obj}>")
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
    Rails.logger.info("terms: #{YAML::dump(wheres)}")
    subjects = { }
    wheres.each do |t|
      subjects[t[0]] ||= { }
      subjects[t[0]][t[1]] ||= [ ]
      subjects[t[0]][t[1]] << t[2]
    end

    Rails.logger.info("subjects: #{YAML::dump(subjects)}")

    
    # now look for patterns -- patterns may indicate a sub-query
    # or an object enclosure

    # Array: type => rdf:Bag, rdf:Seq, rdf:Alt
    #        child => _1, _2, ...
    patterns = self.find_patterns(subjects)

    return { :terms => wheres, :patterns => patterns, :subjects => subjects }
  end

  @@rdf_patterns = [
#    [ 'Array', {
#      :rdf_type => [RDF_NS + 'Bag', RDF_NS + 'Seq', RDF_NS + 'Alt'],
#      :required_predicates => [ RDF_NS + '_1' ],
#      :implementation => RdfPatterns::Array
#    } ],
#    [ 'Array2', {
#      :required_predicates => [ RDF_NS + 'first' ],
#      :required_triples => [
#        [ RDF_NS + 'rest', RDF_NS + 'nil' ]
#      ],
#      :implementation => RdfPatterns::Array2
#    } ],
  ]

  def self.find_patterns(subjects)
    pats = { }

    return pats

    # our first run is based on rdf_type
    # then we choose based on fit with sub-graph expectations
    subjects.each_pair do |var, triples|
      opts = @@rdf_patterns.select{ |p| p[1][:rdf_type].nil? || p[1][:rdf_type].empty? }.collect{|p| p[0] }
      @@rdf_patterns.each do |p|
        t = p[0]
        next if opts.include?(t)
        r = p[1]
        if r[:rdf_type].include?(triples[RDF_NS+'type'].to_s)
          opts << t
        end
      end
      opts = opts.uniq
      Rails.logger.info("Possibilities: #{opts.join(', ')}")

      nopts = [ ]
      opts.each do |t|
        # check graph requirements
        # required elements must be present
        # optional requirements break ties
        Rails.logger.info("Looking at patterns for #{t}")
        @@rdf_patterns.select{ |p| p[0] == t }.collect{|p| p[1]}.each do |r|
          #Rails.logger.info("Info: #{YAML::dump(r)}")
          next if r[:required_predicates].nil? && r[:required_triples].nil?
          if !r[:required_predicates].nil?
            missing_p = false
            r[:required_predicates].each do |p|
              missing_p = true if triples[p].nil? || triples[p].select{ |o| o.is_a?(Array) && o[0] =~ /^\?/ || !o.is_a?(Array) && o =~ /^\?/}.empty?
            end
            next if missing_p
          end

          if !r[:required_triples].nil?
            missing_t = false
            r[:required_triples].each do |ts|
              Rails.logger.info("Require: <#{ts[0]}|#{ts[1]}>")
              Rails.logger.info("Available objects: #{triples[ts[0]].join(" :::: ")}")
              missing_t = true if triples[ts[0]].nil? || triples[ts[0]].select{ |o| !o.is_a?(Array) && o.to_s == ts[1] || o.is_a?(Array) && o[0].to_s == ts[1] }.empty?
            end
            next if missing_t
          end
          nopts << t
        end
      end

      if nopts.size > 1
        # disambiguate based on optional patterns
      elsif nopts.size == 1
        pats[var] = ((@@rdf_patterns.select{ |p| p[0] == nopts.first }.first)[1][:implementation].new rescue nil)
      end
    end
    return pats
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
    sub_selects = [ ]
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
    Rails.logger.info("bgp: #{YAML::dump(bgp)}")

    expr_parser = Fabulator::Expr::Parser.new
    from = []
    joins = []
    vars = self.vars_from_bgp(bgp)
    sql_args[:from] = vars[:froms].join(", ")
    vars = vars[:vars]
    sql2ctx = { }

    # we need to do sub-graphs
    subs = { }
    bgp[:patterns].each_pair do |var, handler|
      terms = [ ]
      new_vars = { }
      patterns = { }
      varstack = [ var ]
      provides = [ ]
      while !varstack.empty?
        v = varstack.shift
        nt = bgp[:terms].select{ |t| t[0] == v }
        nv = nt.select { |t| t[2].is_a?(Array) && t[2][0] =~ /^\?/ || !t[2].is_a?(Array) && t[2] =~ /^\?/ }.collect{ |t| t[2].is_a?(Array) ? t[2][0] : t[2] } - new_vars.keys
        nv.each do |vv|
          new_vars[vv] = vars[vv]
        end
        terms = terms + nt
        varstack = varstack + nv
        provides = provides + nv
      end
      new_vars.keys.select{ |k| !bgp[:patterns][k].nil? }.each do |k|
        patterns[k] = bgp[:patterns][k]
      end
      subs[var] = handler.bgp_to_sql({
        :terms => terms,
        #:vars => vars,
        :patterns => patterns,
        :root => var,
        :provides => provides,
      })
      subs[var][:handler] = handler
    end
    sql_args[:sub_queries] = subs

    # Build the select statement
    select = []
    var_id = 1
    vars.each_pair do |v,i|
      next if v =~ /^[{_]/
      if !sql2ctx[v]
        sql2ctx[v] = "var_#{var_id}"
      end
      #if !sql_args[:sub_queries][v].nil?
        # let pattern implementation handle things
      if i[0] == :predicate && !(i[1] =~ /^\?/)
        select << "#{i[1]}.predicate_id AS #{sql2ctx[v]}_id"
      elsif i[0] == :object
        select << "#{i[1]}.object_type AS #{sql2ctx[v]}_type, #{i[1]}.object_id AS #{sql2ctx[v]}_id"
      elsif !(i[1] =~ /^\?/) # i[0] == :subject
        select << "#{i[1]}.subject_id AS #{sql2ctx[v]}_id"
      end
      Rails.logger.info("Last select: [#{select.last}]\ni: <#{i[0]}|#{i[1]}>")
      var_id = var_id + 1
    end
    sql_args[:select] = select.join(", ")
    sql_args[:sql_to_ctx] = sql2ctx.invert

    where = [ ]
    where_params = [ ]
    bgp[:terms].size.times do |i|
      this_table = "rs_#{i}"
      if !bgp[:patterns][bgp[:terms][i][0]].nil?
        # let pattern handler handle this
      elsif bgp[:terms][i][0] =~ /^\?(.*)$/
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
      if !bgp[:patterns][bgp[:terms][i][0]].nil?
        # let pattern handler handle this
      elsif bgp[:terms][i][1] =~ /^\?(.*)$/
        p_var = $1
        if this_table != vars[p_var][1] && vars[p_var][0] == :predicate
          where << %{#{this_table}.predicate_id = #{vars[p_var][1]}.predicate_id}
        end
      elsif bgp[:terms][i][1] =~ /^http:\/\/www.w3.org\/1999\/02\/22-rdf-syntax-ns#_[1-9]\d*$/
        rr_n = "rr_#{joins.size}"
        joins << %{LEFT JOIN rdf_resources #{rr_n} ON #{rr_n}.id = #{this_table}.predicate_id}
        where << %{#{rr_n}.rdf_namespace_id = %s AND #{rr_n}.local_name LIKE '_%%'}
        where_params << [ :namespace, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' ]
      else
        where << %{#{this_table}.predicate_id = %s}
        where_params << [ :resource, bgp[:terms][i][1] ]
      end
      #if !bgp[:patterns][bgp[:terms][i][0]].nil?
        # let pattern handler handle this
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
            if o_var =~ /^\?/
              where << %{
                (
                #{this_table}.object_type = #{vars[o_var][1]}.object_type AND
                #{this_table}.object_id   = #{vars[o_var][1]}.object_id
                OR
                #{this_table}.object_type IS NULL AND
                #{this_table}.object_id   IS NULL
                )
              }
            else
              where << %{
                #{this_table}.object_type = #{vars[o_var][1]}.object_type AND
                #{this_table}.object_id   = #{vars[o_var][1]}.object_id
              }
            end
          elsif this_table != vars[o_var][1]
            if o_var =~ /^\?/
              where << %{
                (
                #{this_table}.object_type = 'RdfResource' AND
                #{this_table}.object_id = #{vars[o_var][1]}.subject_id
                OR
                (#{this_table}.object_type = 'RdfResource' OR
                 #{this_table}.object_type IS NULL) AND
                #{this_table}.object_id IS NULL
                )
              }
            else
              where << %{
                #{this_table}.object_type = 'RdfResource' AND
                #{this_table}.object_id = #{vars[o_var][1]}.subject_id
              }
            end
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
