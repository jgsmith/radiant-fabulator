module Fabulator
  module Core
  class Parameter
    attr_accessor :name

    def required?
      @required
    end

    def param_names
      [ @name ]
    end

    def compile_xml(xml, c_attrs = { })
      @name = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
      @constraints = [ ]
      @filters = [ ]
      @required = (xml.attributes.get_attribute_ns(FAB_NS, 'required').value rescue 'false')
      attrs = ActionLib.collect_attributes(c_attrs, xml)

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
            @constraints << Constraint.new.compile_xml(e, attrs)
          when 'filter':
            @filters << Filter.new.compile_xml(e, attrs)
          when 'value':
            @constraints << Constraint.new.compile_xml(e, attrs)
        end
      end
      self
    end

    def get_context(context)
      context.traverse_path(@name)
    end

    def apply_filters(context)
      filtered = [ ]
      @filters.each do |f|
        #Rails.logger.info("filter: #{f}")
        context.each do |c|
          filtered = filtered + f.run(c.traverse_path(@name))
        end
      end
      filtered
    end

    def apply_constraints(context)
      res = { :missing => [], :invalid => [], :valid => [], :messages => [] }
      items = context.collect{ |c| c.traverse_path(@name) }.flatten
      if items.empty?
        res[:missing] = [ (context.path + '/' + @name).gsub(/\/+/, '/') ]
      elsif @constraints.empty? # make sure something exists
        res[:valid] = items
      elsif @all_constraints
        @constraints.each do |c|
          items.each do |item|
            if c.test_constraint(i)
              res[:valid] << i
            else
              res[:invalid] << i
              res[:messages] << c.error_message(i)
            end
          end
        end
      else
        items.each do |item|
          passed = @constraints.select {|c| c.test_constraint(i) }
          if passed.empty?
            res[:invalid] << i
            res[:messages] << [ @constraints.collect { |c| c.error_message(i) } ]
          else
            res[:valid] << i
          end
        end
      end

      return res
    end

    def test_constraints(context)
      return true if @constraints.empty?
      if @all_constraints
        @constraints.each do |c|
          return false unless c.test_constraint(context.traverse_path(@name))
        end
        return true
      else
        @constraints.each do |c|
          return true if c.test_constraint(context.traverse_path(@name))
        end
        return false
      end
    end
  end
  end
end
