module Fabulator
  module Core
  module Actions
  class Choose
    def compile_xml(xml, c_attrs = {})
      @choices = [ ]
      @default = nil
      attrs = ActionLib.collect_attributes(c_attrs, xml)

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'when':
            @choices << When.new.compile_xml(e, attrs)
          when 'otherwise':
            @default = When.new.compile_xml(e, attrs)
        end
      end
      self
    end

    def run(context)
      @choices.each do |c|
        if c.run_test(context)
          return c.run(context)
        end
      end
      return @default.run(context) unless @default.nil?
      return []
    end
  end

  class When
    def compile_xml(xml, c_attrs = {})
      #@test = (xml.attributes.get_attribute_ns(FAB_NS, 'test').value rescue nil)
      #if !@test.nil?
        #p = Fabulator::XSM::ExpressionParser.new
        #@test = p.parse(@test, xml)
      #end

      @test = ActionLib.get_local_attr(xml, FAB_NS, 'test', { :eval => true })

      @actions = ActionLib.compile_actions(xml, c_attrs)
      self
    end

    def run_test(context)
      return true if @test.nil?
      result = @test.run(context).collect{ |a| !!a.value }
      return false if result.nil? || result.empty? || !result.include?(true)
      return true
    end

    def run(context)
      # do queries, denials, assertions in the order given
      res = [ ]
      @actions.each do |action|
        res = action.run(context)
      end
      return res
    end
  end

  class If
    def compile_xml(xml, c_attrs = {})
      @test = ActionLib.get_local_attr(xml, FAB_NS, 'test', { :eval => true })
      @actions = ActionLib.compile_actions(xml, c_attrs)
      self
    end

    def run(context)
      return [ ] if @test.nil?
      test_res = @test.run(context).collect{ |a| !!a.value }
      return [ ] if test_res.nil? || test_res.empty? || !test_res.include?(true)
      res = [ ]
      @actions.each do |action|
        res = action.run(context)
      end
      return res
    end
  end
  end
  end
end
