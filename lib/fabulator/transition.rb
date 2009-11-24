module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class Transition
    attr_accessor :state, :validations

    def initialize(xml)
      # manage validations without Lua, if we can
      # only use Lua if we have to
      # model data as RDF?
      # worry about data transformation later

      @state = xml.attributes.get_attribute_ns(FAB_NS, 'view').value

      @groups = { }
      @params = { }
      @required_params = [ ]
      @assert_deny = [ ]
      @assertion_denial = [ ]

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'when':
            e.each_element do |ee|
              next unless ee.namespaces.namespace.href == FAB_NS
              case ee.name
                when 'group':
                  g = Group.new(ee)
                  @groups[g.name] = g
                  @required_params = @required_params + g.required_params
                when 'param':
                  p = Parameter.new(ee)
                  @params[p.name] = p
                  @required_params << p.name if p.required?
              end
            end
          when 'rdf-assert':
            @assert_deny << Assert.new(e)
          when 'rdf-deny':
            @assert_deny << Deny.new(e)
          when 'rdf-assertion':
            @assertion_denial << Assertion.new(e)
          when 'rdf-denial':
            @assertion_denial << Denial.new(e)
        end
      end
    end

    def param_names
      (@groups.collect{|w| w.param_names}.flatten + @params.keys).uniq
    end

    def validate_params(params)
      f_p = self.apply_filters(params)

      res = { :missing => [ ], :valid => { }, :invalid => [ ], :unknown => [ ], :errors => [ ] }
      res[:missing] = @required_params.select {|k| f_p[k].nil? || f_p[k].blank? }
      pn = self.param_names
      res[:unknown] = f_p.keys.select{|k| !pn.include?(k) }
      res[:missing] = pn.select{|k| f_p[k].nil? }

      @groups.each do |g|
        if !g.test_constraints(f_p)
          # remove fields constrained by g
          res[:invalid] = res[:invalid] + g.param_names
          # need to get errors
        end
      end

      @params.each do |k,p|
        if !p.test_constraints(f_p)
          res[:invalid] << k
        end
      end

      res[:valid] = f_p
      res[:invalid].uniq!
      res[:invalid].each do |k|
        res[:valid].delete(k)
      end
      res[:unknown].each do |k|
        res[:valid].delete(k)
      end
      res[:unknown] = res[:unknown] - [ 'url', 'action', 'controller', 'id' ]

      res[:score] = (res[:valid].size+1)*(params.size)
      res[:score] = res[:score] / (res[:missing].size + 1)
      res[:score] = res[:score] / (res[:invalid].size + 1)
      res[:score] = res[:score] / (res[:unknown].size + 1)
      return res
    end

    def apply_filters(params)
      @groups.each do |g|
        params = g.apply_filters(params)
      end
      return params
    end

    def run(data)
    end
  end
end
