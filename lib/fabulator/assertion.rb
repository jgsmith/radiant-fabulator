module Fabulator
  class Assertion
    attr_accessor :as

    def initialize(xml, def_model = nil)
      @model = xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model
      # f:select ...
      xsm_exp_parser = Fabulator::XSM::ExpressionParser.new
      @from  = xsm_exp_parser.parse((xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '/'))
      @arcs = [ ]
      xml.each_element do |e|
        if e.namespaces.namespace.href == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' && e.name == 'RDF'
          @arcs << RdfModel.build_arcs(e)
        end
      end
    end

    def run(context)
      return true if self.rdf_model.nil?
      data = @from.run(context.data)
      if data.is_a?(Array)
        data.each do |d|
          self.execute_arcs(d)
        end
      else
        self.execute_arcs(data)
      end
    end

    def rdf_model
      @rdf_model ||= RdfModel.first(:conditions => [ 'name = ?', @model ])
      @rdf_model
    end

  protected

    def execute_arcs(data)
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
      return true
    end

    def add_triple(data,bnodes,s,t)
      case t[0]
        when 0:
          rdf_model.add_statement(
            RdfResource.from_uri(s),
            RdfResource.from_uri(t[1]),
            self.resource_from_data(data,t[2])
          )
        when 1:
          if s =~ /^\?_(.*)/
            v = $1
            self.rdf_model.add_statement(
              RdfResource.from_uri(bnodes[v]),
              RdfResource.from_uri(t[1]),
              self.resource_from_data(data,t[2])
            )
          else
            self.rdf_model.add_statement(
              self.resource_from_data(data,s),
              self.resource_from_data(data,t[1]),
              self.resource_from_data(data,t[2])
            )
          end
        when 2:
          # predicate is variable
          if t[1] =~ /^\?_(.*)/ # blank node predicate (Bag/Seq)
            possible = rdf_model.find_statements(
              RdfResource.from_uri(s),
              nil,
              self.resource_from_data(data,t[2])
            ).select{|s| s.predicate.rdf_namespace.namespace == RDFS_NS}
            if possible.empty?
              # instantiate
            
            else
              # record value for predicate
            end
          elsif t[1] =~ /^\?(.*)/
            v = $1
            return if data.get_values(v).first.nil?
            # variable predicate - we need to get from data
            self.rdf_model.add_statement(
              RdfResource.from_uri(s),
              self.resource_from_data(data,t[1]),
              self.resource_from_data(data,t[2])
            )
          end
        when 3:
          # subject and predicate are variable
          if s =~ /^\?_(.*)/
            v = $1
            return if bnodes[v].nil?
            self.add_triple(data,bnodes,bnodes[v],[2, t[1], t[2]])
          elsif s =~ /^\?(.*)/
            v = $1
            data_v = data.get_values(v).first
            return if data_v.nil?
            self.add_triple(data,bnodes,data_v,[2, t[1], t[2]])
          end
        when 4:
          # object is variable
          if t[2].is_a?(Array)
            self.rdf_model.add_statement(
              RdfResource.from_uri(s),
              RdfResource.from_uri(t[1]),
              self.resource_from_data(data,t[2])
            )
          elsif t[2] =~ /^\?_(.*)/
            v = $1
            if bnodes[v].nil?
              possible = self.rdf_model.find_statements(
                RdfResource.from_uri(s),
                RdfResource.from_uri(t[1]),
                nil
              ).select {|n| n.bnode? }
              if possible.empty?
                b = RdfResource.create_bnode
                bnodes[v] = b.uri
                self.rdf_model.add_statement(
                  RdfResource.from_uri(s),
                  RdfResource.from_uri(t[1]),
                  b
                )
              else
                bnodes[v] = possible.first.uri
              end
            else
              self.rdf_model.add_statement(
                RdfResource.from_uri(s),
                RdfResource.from_uri(t[1]),
                RdfResource.from_uri(bnodes[v])
              )
            end
          else
            t[2] =~ /^\?(.*)/
            v = $1
            if data.get_values(v).first.nil?
              possible = self.rdf_model.find_statements(
                RdfResource.from_uri(s),
                RdfResource.from_uri(t[1]),
                nil
              ).select{ |n| !n.bnode? && !n.literal? }
              if possible.empty?
                self.rdf_model.add_statement(
                  RdfResource.from_uri(s),
                  RdfResource.from_uri(t[1]),
                  self.resource_from_data(data,t[2])
                )
              else
                data.create_child(v, possible.first.uri)
              end
            else
              self.rdf_model.add_statement(
                RdfResource.from_uri(s),
                RdfResource.from_uri(t[1]),
                self.resource_from_data(data,t[2])
              )
            end
          end
        when 5:
          # object and subject are variable
          if s =~ /^\?_(.*)/ # bnode
            v = $1
            return if bnodes[v].nil?
            self.add_triple(data,bnodes,bnodes[v],[4, t[1], t[2]])
          else 
            s =~ /^\?(.*)/
            v = $1
            data_v = data.get_values(v).first
            if data_v.nil?
              ss = self.rdf_model.create_resource
              data.create_child(v,ss.uri)
              self.add_triple(data,bnodes,ss.uri,[4, t[1], t[2]])
            else
              self.add_triple(data,bnodes,data_v,[4, t[1], t[2]])
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
        else
          return RdfResource.from_uri(data_v)
        end
      else
        return RdfResource.from_uri(r)
      end
    end
  end
end
