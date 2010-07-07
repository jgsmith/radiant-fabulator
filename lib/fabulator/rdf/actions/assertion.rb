module Fabulator
  module Rdf
  module Actions
  class Assertion
    attr_accessor :as

    def compile_xml(xml, c_attrs = { })
      @model_x = ActionLib.get_attribute(RDFA_NS, 'model', c_attrs)
      @from = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true, :default => '/' })
      @mode_x = ActionLib.get_local_attr(xml, FAB_NS, 'mode', { :default => 'overwrite' })

      @arcs = [ ]
      xml.each_element do |e|
        # allow other types of queries -- but simple rdf templates for now
        if e.namespaces.namespace.href == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' && e.name == 'RDF'
          @arcs << RdfModel.build_arcs(e)
        end
      end
      self
    end

    def run(context, autovivify = false)
      Rails.logger.info("Running an assertion")
      return [] if @model_x.nil?
      @model = @model_x.run(context).first.value
      return [] if @model.nil?
      return [] if self.rdf_model.nil?
      data = @from.run(context)
      @mode = @mode_x.run(context).first.value
      #Rails.logger.info("Data: #{YAML::dump(data)}")
      result = [ ]
      if data.is_a?(Array)
        data.each do |d|
          self.execute_arcs(d)
        end
      else
        self.execute_arcs(data)
      end
      return [ ]
    end

    def rdf_model
      if @rdf_model.nil?
        return nil if @model.nil?
        @rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model ])
      end
      @rdf_model
    end

  protected

    def execute_arcs(data)
      #Rails.logger.info("Running: #{YAML::dump(@arcs)}")
      @arcs.each do |arc_set|
        # we want to make sure all of the arcs are in the database
        # arcs have well-defined nodes (not blank nodes or <rdf:li/> predicates
        # we will need a way of managing order for <rdf:Seq/>uences
        # handle constant triples
        bnodes = { }
        arc_set[:graph].each_pair do |s,triples|
          next if s =~ /^\?/
          triples.each do |t|
            next if t[0] != 0
            self.add_triple(data,bnodes,s,t)
          end
        end
        arc_set[:sorted_vars].each do |v|
          next if arc_set[:graph][v].nil?
          arc_set[:graph][v].each do |t|
            self.add_triple(data,bnodes,v,t)
          end
        end
        arc_set[:graph].each_pair do |s,triples|
          next if arc_set[:sorted_vars].include?(s)
          triples.each do |t|
            next if t[0] == 0
            self.add_triple(data,bnodes,s,t)
          end
        end
      end
    end

    def add_triple2(s,p,o)
      #Rails.logger.info("add_triple2(#{s}, #{o}, #{p})")
      #Rails.logger.info("  mode: #{@mode}")
      if s.nil? || p.nil? || o.nil?
        #Rails.logger.info(" Uh oh... something's nil that shouldn't be: <#{s}|#{p}|#{o}>")
        return
      end
      return if self.rdf_model.count_statements(s,p,o) > 0
      if @mode == 'overwrite' && !o.bnode?
        #Rails.logger.info("Removing statements first")
        self.rdf_model.find_statements(s,p,nil).each do |st|
          self.rdf_model.remove_statement(st.subject, st.predicate, st.object)
        end
      end
      self.rdf_model.add_statement(s,p,o)
    end

    def add_triple(data,bnodes,s,t)
      #Rails.logger.info("Adding triple (#{s}, #{t[0]}, #{t[1]}, #{t[2]})")
      t0 = t[0]
      if t0 & 16 && s =~ /^\{(.*)\}$/
        t0 = t0 - 16
#Rails.logger.info("Data: #{YAML::dump(data)}")
#Rails.logger.info("Running expression: [#{$1}]")
        s = data.eval_expression($1)
        #Rails.logger.info("Found: #{YAML::dump(s)}")
        s = (s.first.value rescue nil)
      end
      if t0 & 32 && t[1] =~ /^\{(.*)\}$/
        t0 = t0 - 32
        p = data.eval_expression($1).first.value
      else
        p = t[1]
      end
      if t0 & 64 && t[2] =~ /^\{(.*)\}$/
        t0 = t0 - 64
        o = data.eval_expression($1).first.value
      else
        o = t[2]
      end
        
      case t0
        when 0:
          self.add_triple2(
            RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
            RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
            self.resource_from_data(data,o)
          )
        when 1:
          if s =~ /^\?_(.*)/
            v = $1
            self.add_triple2(
              RdfResource.from_uri(bnodes[v], self.rdf_model.rdf_namespace),
              RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
              self.resource_from_data(data,o)
            )
          else
            self.add_triple2(
              self.resource_from_data(data,s),
              self.resource_from_data(data,p),
              self.resource_from_data(data,o)
            )
          end
        when 2:
          # predicate is variable
          if t[1] =~ /^\?_(.*)/ # blank node predicate (Bag/Seq)
            possible = rdf_model.find_statements(
              RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
              nil,
              self.resource_from_data(data,o)
            ).select{|s| s.predicate.rdf_namespace.rdf_namespace == RDFS_NS}
            if possible.empty?
              # instantiate
            
            else
              # record value for predicate
            end
          elsif t[1] =~ /^\?(.*)/
            v = $1
            return if data.get_values(v).first.nil?
            # variable predicate - we need to get from data
            self.add_triple2(
              RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
              self.resource_from_data(data,p),
              self.resource_from_data(data,o)
            )
          end
        when 3:
          # subject and predicate are variable
          if s =~ /^\?_(.*)/
            v = $1
            return if bnodes[v].nil?
            self.add_triple(data,bnodes,bnodes[v],[2, p, o])
          elsif s =~ /^\?(.*)/
            v = $1
            data_v = data.get_values(v).first
            return if data_v.nil?
            self.add_triple(data,bnodes,data_v,[2, p, o])
          end
        when 4:
          # object is variable
          if t[2].is_a?(Array)
            #Rails.logger.info("4: <#{s}|#{p}|#{o}> t:[#{t.join("|")}]")
            self.add_triple2(
              RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
              RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
              self.resource_from_data(data,o)
            )
          elsif t[2] =~ /^\?_(.*)/
            v = $1
            if bnodes[v].nil?
              possible = self.rdf_model.find_statements(
                RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                nil
              ).select {|n| n.bnode? }
              if possible.empty?
                b = RdfResource.create_bnode
                bnodes[v] = b.uri
                self.add_triple2(
                  RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                  RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                  b
                )
              else
                bnodes[v] = possible.first.uri
              end
            else
              self.add_triple2(
                RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                RdfResource.from_uri(bnodes[v], self.rdf_model.rdf_namespace)
              )
            end
          else
            t[2] =~ /^\?(.*)/
            v = $1
            if data.get_values(v).first.nil?
              possible = self.rdf_model.find_statements(
                RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                nil
              ).select{ |n| !n.bnode? && !n.literal? }
              if possible.empty?
                self.add_triple2(
                  RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                  RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                  self.resource_from_data(data,o)
                )
              else
                data.create_child(v, possible.first.uri)
              end
            else
              self.add_triple2(
                RdfResource.from_uri(s, self.rdf_model.rdf_namespace),
                RdfResource.from_uri(p, self.rdf_model.rdf_namespace),
                self.resource_from_data(data,o)
              )
            end
          end
        when 5:
          # object and subject are variable
          if s =~ /^\?_(.*)/ # bnode
            v = $1
            return if bnodes[v].nil?
            self.add_triple(data,bnodes,bnodes[v],[4, p, o])
          else 
            s =~ /^\?(.*)/
            v = $1
            data_v = data.get_values(v).first
            if data_v.nil?
              ss = self.rdf_model.create_resource
              data.create_child(v,ss.uri)
              self.add_triple(data,bnodes,ss.uri,[4, p, o])
            else
              self.add_triple(data,bnodes,data_v,[4, p, o])
            end
          end
        when 6:
          # predicate and object are variable
        when 7:
          # all are variable
      end
    end

    def resource_from_data(data, r)
      if r.is_a?(Array)
        # object literal
        if r[0] =~ /^\?(.*)/
          v = $1
          if data.get_values(v).first.nil?
            # we do nothing
            return nil
          else
            return RdfLiteral.build(data.get_values(v).first, r[1])
          end
        else
          return RdfLiteral.build(r[0], r[1])
        end
      elsif r =~ /^\?_(.*)/
        # blank node
        
      elsif r =~ /^\?(.*)/
        v = $1
        data_v = data.get_values(v).first
        if data_v.nil?
          r = self.rdf_model.create_resource
          data.create_child(v, r.uri)
          return r
        elsif data_v == ''
          return nil
        else
          return RdfResource.from_uri(data_v, self.rdf_model.rdf_namespace)
        end
      else
        return RdfResource.from_uri(r, self.rdf_model.rdf_namespace)
      end
    end
  end
  end
  end
end
