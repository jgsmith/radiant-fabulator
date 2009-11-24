module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class Group
    attr_accessor :name, :params
    def initialize(xml)
      @name = (xml.attributes.get_attribute_ns(FAB_NS, 'name').value rescue '')

      @params = { }
      @constraints = [ ]
      @filter = [ ]
      @required_params = [ ]
      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS

        case e.name
          when 'param':
            v = Parameter.new(v)
            @params[v.name] = v
            @required_params << v.name if v.required?
          when 'constraint':
            @constraints << Constraint.new(e)
          when 'filter':
            @filters << Filter.new(e)
        end
      end
    end

    def param_names
      @params.keys
    end

    def required_params
      @required_params
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
end
