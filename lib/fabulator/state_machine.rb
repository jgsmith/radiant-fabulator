#
# For now, use Lua for the code we execute on transition
# we may eventually want to change this, but it's the quickest way for now
#
module Fabulator
  FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  class StateMachine
    attr_accessor :states

    def initialize(xml,logger = nil)
      # /statemachine/states
      @states = { }
      @queries = [ ]
      @assert_deny = [ ]
      @default_model = xml.root.attributes.get_attribute_ns(FAB_NS,'rdf-model').value rescue nil
      xml.root.each_element do |child|
        next unless child.namespaces.namespace.href == FAB_NS
        case child.name
          when 'view':
            cs = State.new(child)
            @states[cs.name] = cs
          when 'rdf-query':
            @queries << Query.new(child, @default_model)
          when 'rdf-assert':
            @assert_deny << Assert.new(child, @default_model)
          when 'rdf-deny':
            @assert_deny << Deny.new(child, @default_model)
        end
      end
    end

    def context
      if @context.nil?
        # we need to initialize ourselves
        @context = { :state => 'start', :data => { } }
        @queries.each do |q|
          p = (q.as || '').split('/')
          t = @context[:data]
          last_p = p.pop
          p.each do |c|
            t[c] = { } if t[c].nil?
            t = t[c]
          end
          t[last_p] = q.run
        end
        @assert_deny.each do |ad|
          if !ad.run
            @context[:state] = ad.state
            break
          end
        end
      end
      @context
    end

    def context=(c)
      @context = c
    end

    def run(params)
      c = self.context
      current_state = @states[c[:state]]
      if current_state
        # select transition
        # possible get some errors
        # run transition, and move to new state as needed
        best_transition = current_state.select_transition(params)
      end
    end

    def state
      self.context[:state]
    end

    def state_names
      (@states.keys.map{ |k| @states[k].states }.flatten + @states.keys).uniq
    end
  end

  class Query
    attr_accessor :as

    def initialize(xml, def_model = nil)
      @model = xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model
      @as    = xml.attributes.get_attribute_ns(FAB_NS, 'as').value rescue ''
      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end
    end

    def run
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model ])
      results = [ ]
      return results if rdf_model.nil?
      @sql.each do |s|
        Rails.logger.info(YAML::dump(s))
        conditions = [ s[:simple_where] ]
        s[:where_params].each do |p|
          if p == :model
            conditions << rdf_model.id
          elsif p.is_a?(Array)
            case p[0]
              when :literal:
                conditions << (RdfLiteral.first(:conditions => [ 'obj_lit = ?', p[1] ]).id rescue 0)
              when :resource:
                conditions << (RdfResource.from_uri(p[1]) rescue 0)
              when :namespace:
                conditions << (RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0)
            end
          end
        end
        results = results + RdfQueryResult.find_by_sql(%{
          SELECT DISTINCT #{s[:select]}
          FROM #{s[:from]}
          #{s[:joins]}
          WHERE #{RdfModel.sanitize_where(conditions)}
        })
      end
      results.uniq!
      results
    end
  end

  class AssertDeny
    attr_accessor :state

    def initialize(xml, def_model = nil)
      @model = xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model
      @state = xml.attributes.get_attribute_ns(FAB_NS, 'go-to').value rescue nil
      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end
      #fc = xml.elements.first
      #if fc.namespace == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' &&
      #   fc.local_name == 'RDF'
      #  @sql = RdfModel.build_query(fc.to_s)
      #end
      #@sql[:type_ns] = fc.namespace
      #@sql[:type_ln] = fc.local_name
    end

    def count(s)
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model ])
      conditions = [ s[:simple_where] ]
      s[:where_params].each do |p|
        if p == :model
          conditions << rdf_model.id
        elsif p.is_a?(Array)
          case p[0]
            when :literal:
              conditions << (RdfLiteral.first(:conditions => [ 'obj_lit = ?', p[1] ]).id rescue 0)
            when :resource:
              conditions << (RdfResource.from_uri(p[1]) rescue 0)
            when :namespace:
              conditions << (RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0)
          end
        end
      end
      RdfQueryResult.count_by_sql(%{
        SELECT COUNT(#{s[:select].gsub(/AS.+$/,'')})
        FROM #{s[:from]}
        #{s[:joins]}
        WHERE #{RdfModel.sanitize_where(conditions)}
        LIMIT 1
      })
    end
  end

  class Assert < AssertDeny
    def run
      @sql.each do |s|
        return true if self.count(s) > 0
      end
      return false
    end
  end

  class Deny < AssertDeny
    def run
      @sql.each do |s|
        return true if self.count(s) == 0
      end
      return false
    end
  end

  class State
    attr_accessor :name, :transitions

    def initialize(xml)
      @name = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
      @transitions = [ ]
      xml.each_element do |e|
        next unless e.namespaces.namespace == FAB_NS && e.name == 'goes-to'
        @transitions << Transition.new(e)
      end
    end

    def states
      @transitions.map { |t| t.state }.uniq
    end

    def select_transition(params)
      # we need hypthetical variables here :-/
      best_match = nil
      @transitions.each do |t|
        res = t.validate_params(params)
        if res[:missing].empty? && res[:errors].empty?
          return res
        end
        if best_match.nil? || res[:score] > best_match[:score]
          best_match = res
        end
      end
      return best_match
    end
  end

  class Transition
    attr_accessor :state, :validations

    def initialize(xml)
      # manage validations without Lua, if we can
      # only use Lua if we have to
      # model data as RDF?
      # worry about data transformation later

      @state = xml.attributes.get_attribute_ns(FAB_NS, 'view').value

      @groups = { }
      
     # REXML::XPath.match(xml, './group').each do |g|
     #   g = Group.new(g)
     #   @groups[g.name] = g
     # end

     @params = { }
     # REXML::XPath.match(xml, './param').each do |v|
     #   v = Parameter.new(v)
     #   @params[v.name] = v
     # end

     # @required_params = @params.keys.select{|k| @params[k].required}
    end

    def param_names
      (@groups.collect{|g| g.param_names}.flatten + @params.keys).uniq
    end

    def validate_params(params)
      f_p = params
      self.apply_filters(params)

      res = { }
      res[:missing] = @required_params.select {|k| params[k].nil? || params[k].blank? }
      
    end

    def apply_filters(params)
      @groups.each do |g|
        g.apply_filters(params)
      end
      @params.keys.each do |p|
        @params[p].apply_filters(params)
      end
    end
      
  end

  class Group
    attr_accessor :name, :params
    def initialize(xml)
      @name = REXML::XPath.match(xml, './@name').to_s

      @params = { }
      REXML::XPath.match(xml, './param').each do |v|
        v = Parameter.new(v)
        @params[v.name] = v
      end
      @constraints = [ ]
      REXML::XPath.match(xml, './constraint').each do |c|
        @constraints << Constraint.new(c)
      end
      @filters = [ ]
      REXML::XPath.match(xml, './filter').each do |f|
        @filters << Filter.new(f)
      end
    end

    def param_names
      @params.keys
    end

    def apply_filters(params)
      fields = self.param_names
      @filters.each do |f|
        f.apply_filter(params[@name],fields)
      end

      @params.keys.each do |p|
        @params[p].apply_filters(params[@name])
      end
    end

    def test_constraints(params)
      fields = self.param_names
      @params.keys.each do |p|
        return false unless @params[p].test_constraints(params[@name])
      end

      return true if @constraints.empty?

      if @all_constraints
        @constraints.each do |c|
          return false unless c.test_constraints(params[@name], fields)
        end
      else
        @constraints.each do |c|
          return true if c.test_constraints(params[@name], fields)
        end
      end
    end
  end

  class Parameter
    attr_accessor :name

    def initialize(xml)
      @name = REXML::XPath.match(xml, './@name').to_s
      @constraints = [ ]
      REXML::XPath.match(xml, './constraint').each do |c|
        @constraints << Constraint.new(c)
      end
      @filters = [ ]
      REXML::XPath.match(xml, './filter').each do |f|
        @filters << Filter.new(f)
      end
    end

    def apply_filters(params)
      @filters.each do |f|
        f.apply_filter(params, [@name])
      end
    end

    def test_constraints(params)
      return true if @constraints.empty?
      if @all_constraints
        @constraints.each do |c|
          return false unless c.test_constraint(params, [@name])
        end
        return true
      else
        @constraints.each do |c|
          return true if c.test_constraint(params,[@name])
        end
        return false
      end
    end
  end

  # admin interface allows managing of constraints and filters
  class Constraint
    def initialize(xml)
      @type = REXML::XPath.match(xml, './@type').to_s
      @constraints = [ ]
      REXML::XPath.match(xml, './constraint').each do |c|
        @constraints << Constraint.new(c)
      end
    end

    def test_constraint(params, fields)
      # do special ones first
      @sense = !@inverted
      case @type
        when 'all':
          # we have enclosed constraints
          @constraints.each do |c|
            return @sense unless c.test_constraint(params,fields)
          end
          return !@sense
        when 'any':
          @constraints.each do |c|
            return !@sense if c.test_constraint(params,fields)
          end
          return @sense
        when 'range':
          if @requires == 'all'
            fields.each do |f|
              return !@sense if @attributes['floor'] > params[f] || 
                                @attributes['ceil'] < params[f]
            end
            return @sense
          else
            fields.each do |f|
              return @sense if @attributes['floor'] < params[f] || 
                               @attributes['ceil'] > params[f]
            end
            return !@sense
          end
        else
          c = FabulatorConstraint.find_by_name(@type) rescue nil
          return @sense if c.nil?
          return @sense if c.run_constraint(params, fields)
          return !@sense
      end
    end
  end

  class Filter
    def initialize(xml)
      @type = REXML::XPath.match(xml, './@type').to_s
    end

    def apply_filter(params, fields)
      # do special ones first
      case @type
        when 'trim':
          fields.each do |f|
            params[f].chomp!
            params[f].gsub!(/^\s*/,'')
            params[f].gsub!(/\s*$/,'')
          end
        when 'downcase':
          fields.each do |f|
            params[f].downcase!
          end
        when 'upcase':
          fields.each do |f|
            params[f].upcase!
          end
        when 'integer':
          fields.each do |f|
            params[f] = params[f].to_i.to_s
          end
        when 'decimal':
          fields.each do |f|
            params[f] = params[f].to_f.to_s
          end
        else
          f = FabulatorFilter.find_by_name(@type) rescue nil
          return if f.nil?
          f.run_filter(params, fields)
      end
    end
  end

  class Script
    def initialize(xml)
      
    end
  end
end
