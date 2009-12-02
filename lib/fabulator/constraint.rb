module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  # admin interface allows managing of constraints and filters
  class Constraint
    def initialize(xml)
      @constraints = [ ]
      @values = [ ]
      @attributes = { }
      @inverted = (xml.attributes.get_attribute_ns(FAB_NS, 'sense').value.downcase rescue 'false')
      @inverted = (@inverted == 'true' || @inverted == 'yes') ? true : false
      if xml.name == 'value'
        @c_type = 'any'
        @values << xml.content
      else
        @c_type = xml.attributes.get_attribute_ns(FAB_NS, 'type').value

        xml.each_attr do |attr|
          next unless attr.ns.href == FAB_NS
          next if attr.name == 'type' || attr.name == 'sense'
          @attributes[attr.name] = attr.value
        end
        xml.each_element do |e|
          next unless e.namespaces.namespace.href == FAB_NS
          case e.name
            when 'constraint':
              @constraints << Constraint.new(e)
            when 'value':
              @values << e.content
          end
        end
      end
    end

    def test_constraint(params, fields)
      # do special ones first
      @sense = !@inverted
      case @c_type
        when 'all':
          # we have enclosed constraints
          @constraints.each do |c|
            return @sense unless c.test_constraint(params,fields)
          end
          return !@sense
        when 'any':
          if @values.empty?
            @constraints.each do |c|
              return !@sense if c.test_constraint(params,fields)
            end
            return @sense
          else
            fields.each do |f|
              return !@sense unless @values.include?(params[f])
            end
            return @sense
          end
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
          c = FabulatorConstraint.find_by_name(@c_type) rescue nil
          return @sense if c.nil?
          return @sense if c.run_constraint(params, fields)
          return !@sense
      end
    end
  end
end
