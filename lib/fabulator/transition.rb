module Fabulator
  class Transition
    attr_accessor :state, :validations

    def initialize(xml, rdf_model = nil)
      # manage validations without Lua, if we can
      # only use Lua if we have to
      # model data as RDF?
      # worry about data transformation later

      @state = xml.attributes.get_attribute_ns(FAB_NS, 'view').value

      @groups = { }
      @params = { }
      @required_params = [ ]
      @actions = [ ]
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'when':
            @select = (e.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
            @select = (@select.split('/').join('.') + '.').gsub(/\.+/, '.').gsub(/^\./,'') unless @select == ''
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
            @actions << Assert.new(e, @rdf_model)
          when 'rdf-deny':
            @actions << Deny.new(e, @rdf_model)
          when 'rdf-assertion':
            @actions << Assertion.new(e, @rdf_model)
          when 'rdf-denial':
            @actions << Denial.new(e, @rdf_model)
          when 'rdf-query':
            @actions << Query.new(e, @rdf_model)
        end
      end
    end

    def param_names
      (@groups.collect{|w| w.param_names}.flatten + @params.keys).uniq
    end

    def validate_params(context,params)
      if @select == ''
        my_params = params
        my_params.delete('url')
        my_params.delete('action')
        my_params.delete('controller')
        my_params.delete('id')
      else
        my_params = { }
        params.each_pair do |k,v|
          if k[0..@select.length-1] == @select
            my_params[k[@select.length..k.length-1]] = v
          end
        end
      end
      f_p = self.apply_filters(my_params)

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

      if @select == ''
        res[:valid] = f_p
      else
        res[:valid] = { }
        f_p.each_pair do |k,v|
          res[:valid][@select + k] = v
        end
      end
      res[:invalid].uniq!
      res[:invalid] = res[:invalid].collect{|k| @select + k}
      res[:invalid].each do |k|
        res[:valid].delete(k)
      end
      res[:unknown] = res[:unknown].collect{|k| @select + k}
      res[:unknown].each do |k|
        res[:valid].delete(k)
      end

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

    def run(context)
      # do queries, denials, assertions in the order given
      @actions.each do |action|
        if !action.run(context)
          return false
        end
      end
      return true
    end
  end
end
