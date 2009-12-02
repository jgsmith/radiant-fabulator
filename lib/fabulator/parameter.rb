module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class Parameter
    attr_accessor :name

    def required?
      @required
    end

    def initialize(xml)
      @name = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
      @constraints = [ ]
      @filters = [ ]
      @required = (xml.attributes.get_attribute_ns(FAB_NS, 'required').value rescue 'false')

      case @required.downcase
        when 'yes':
          @required = true
        when 'true':
          @required = true
        when 'no':
          @required = false
        when 'false':
          @required = false
      end

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'constraint':
            @constraints << Constraint.new(e)
          when 'filter':
            @filters << Filter.new(e)
          when 'value':
            @constraints << Constraint.new(e)
        end
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
end
