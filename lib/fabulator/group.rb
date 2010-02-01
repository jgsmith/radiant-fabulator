module Fabulator
  class Group
    attr_accessor :name, :params
    def initialize(xml)
      parser = Fabulator::XSM::ExpressionParser.new
      @select = parser.parse((xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue ''), xml)

      @params = { }
      @constraints = [ ]
      @filter = [ ]
      @required_params = [ ]
      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS

        case e.name
          when 'param':
            v = Parameter.new(e)
            @params << v
            @required_params = @required_params + v.names if v.required?
          when 'group':
            v = Group.new(e)
            @params << v
            @required_params = @required_params + v.required_params.collect{ |n| (@name + '/' + n).gsub(/\/+/, '/') }
          when 'constraint':
            @constraints << Constraint.new(e)
          when 'filter':
            @filters << Filter.new(e)
        end
      end
    end

    def apply_filters(context)
      roots = @select.run(context)
      filtered = [ ]

      roots.each do |root|
        @params.each do |param|
          p_ctx = param.get_context(context)
          if !p_ctx.nil? && !p_ctx.empty?
            p_ctx.each do |p|
              @filters.each do |f|
                filtered = filtered + f.apply_filter(p)
              end
            end
          end
          filtered = filtered + param.apply_filters(root)
        end
      end
      filtered.uniq
    end

    def get_context(context)
      @select.run(context)
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
end
