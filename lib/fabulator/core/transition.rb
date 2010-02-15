module Fabulator
  module Core
  class Transition
    attr_accessor :state, :validations

    def compile_xml(xml, c_attrs = { })
      # manage validations without Lua, if we can
      # only use Lua if we have to
      # model data as RDF?
      # worry about data transformation later

      @state = xml.attributes.get_attribute_ns(FAB_NS, 'view').value

      attrs = ActionLib.collect_attributes(c_attrs, xml)

      @groups = { }
      @params = [ ]
      @actions = [ ]

      @actions = ActionLib.compile_actions(xml, attrs)
      parser = Fabulator::XSM::ExpressionParser.new

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'params':
            p_attrs = ActionLib.collect_attributes(attrs, e)
            @select = (e.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
            @select = parser.parse(@select, xml)

            e.each_element do |ee|
              next unless ee.namespaces.namespace.href == FAB_NS
              case ee.name
                when 'group':
                  g = Group.new.compile_xml(ee, p_attrs)
                  @params << g
                when 'param':
                  p = Parameter.new.compile_xml(ee, p_attrs)
                  @params << p
              end
            end
        end
      end
      self
    end

    def param_names
      (@params.collect{|w| w.param_names}.flatten).uniq
    end

    def validate_params(context,params)
      my_params = params
      my_params.delete('url')
      my_params.delete('action')
      my_params.delete('controller')
      my_params.delete('id')
      param_context = Fabulator::XSM::Context.new(
        'ext',
        context.data.roots,
        nil,
        []
      )
      context.data.roots['ext'] = param_context
      param_context.merge_data(my_params)

      filtered = self.apply_filters(@select.run(param_context))

      # 'filtered' has a list of all parameters that have been passed through
      # some kind of filter -- not necessarily ones that have passed a
      # constraint

      res = self.apply_constraints(@select.run(param_context))

#      @groups.each do |g|
#        if !g.test_constraints(f_p)
#          # remove fields constrained by g
#          res[:invalid] = res[:invalid] + g.param_names
#          # need to get errors
#        end
#      end

#      @params.each do |p|
#        if !p.test_constraints(param_context)
#          res[:invalid] = res[:invalid] + p.names
#        end
#      end

#      if @select == ''
#        res[:valid] = f_p
#      else
#        res[:valid] = { }
#        f_p.each_pair do |k,v|
#          res[:valid][@select + k] = v
#        end
#      end
      #res[:valid] = param_context.paths
      #res[:unknown] = param_context.paths
      res[:unknown] = [ ]

      res[:invalid].uniq!
#      res[:invalid] = res[:invalid].collect{|k| @select + k}
      res[:invalid].each do |k|
        res[:valid].delete(k.path)
        res[:unknown].delete(k.path)
      end
      #res[:unknown] = res[:unknown].collect{|k| @select + k}
      res[:unknown].each do |k|
        res[:valid].delete(k)
      end

      res[:score] = (res[:valid].size+1)*(params.size)
      res[:score] = res[:score] / (res[:missing].size + 1)
      res[:score] = res[:score] / (res[:invalid].size + 1)
      res[:score] = res[:score] / (res[:unknown].size + 1)
      return res
    end

    def apply_filters(context)
      @params.each do |p|
        p.apply_filters(context)
      end
    end

    def apply_constraints(context)
      invalid = [ ]
      missing = [ ]
      valid = [ ]
      msgs = [ ]
      @params.each do |p|
        res = p.apply_constraints(context)
        invalid = invalid + res[:invalid]
        missing = missing + res[:missing]
        valid = valid + res[:valid]
        msgs = msgs + res[:messages]
      end
      return { :missing => missing, :invalid => invalid, :valid => valid, :messages => msgs, :unknown => [ ] }
    end

    def run(context)
      # do queries, denials, assertions in the order given
      @actions.each do |action|
        action.run(context)
      end
      return []
    end
  end
  end
end
