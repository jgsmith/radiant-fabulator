module Fabulator
  module Core
  class Group
    attr_accessor :name, :params
    def compile_xml(xml, c_attrs)
      @select = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true })

      attrs = ActionLib.collect_attributes(c_attrs, xml)
      @params = { }
      @constraints = [ ]
      @filter = [ ]
      @required_params = [ ]
      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS

        case e.name
          when 'param':
            v = Parameter.new.compile_xml(e,attrs)
            @params << v
            @required_params = @required_params + v.names if v.required?
          when 'group':
            v = Group.new.compile_xml(e,attrs)
            @params << v
            @required_params = @required_params + v.required_params.collect{ |n| (@name + '/' + n).gsub(/\/+/, '/') }
          when 'constraint':
            @constraints << Constraint.new.compile_xml(e,attrs)
          when 'filter':
            @filters << Filter.new.compile_xml(e,attrs)
        end
      end
      self
    end

    def apply_filters(context)
      roots = @select.nil? ? [ context ] : @select.run(context)
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
end
