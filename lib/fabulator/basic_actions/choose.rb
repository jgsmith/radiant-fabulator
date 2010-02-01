module Fabulator
  module BasicActions
  class Choose
    def initialize(xml, rdf_model = nil)
      @choices = [ ]
      @default = nil
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value r
escue rdf_model)

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'when':
            @choices << When.new(e, @rdf_model)
          when 'otherwise':
            @default = When.new(e, @rdf_model)
        end
      end
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
    def initialize(xml, rdf_model = nil)
      @test = (xml.attributes.get_attribute_ns(FAB_NS, 'test').value rescue nil)
      if !@test.nil?
        p = Fabulator::XSM::ExpressionParser.new
        @test = p.parse(@test, xml)
      end

      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)

      @actions = ActionLib.compile_actions(xml, @rdf_model)
    end

    def run_test(context)
      return true if @test.nil?
      result = context.data.eval_expression(@test)
      return false if result.nil? || result.empty? || !result.first
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
  end
end
