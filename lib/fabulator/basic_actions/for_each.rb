module Fabulator
  module BasicActions
  class ForEach
    def initialize(xml, rdf_model = nil)
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
      parser = Fabulator::XSM::ExpressionParser.new
      @select = (parser.parse(@select, xml) rescue nil)
      @sort = [ ]

      @actions = ActionLib.compile_actions(xml, rdf_model)

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'sort-by':
            @sort << Sort.new(e, @rdf_model)
        end
      end
    end

    def run(context)
      items = @select.run(context)
      if !@sort.empty?
        items = items.sort_by{ |i| @sort.collect{|s| s.run(i) }.join("\0") }
      end
      res = [ ]
      items.each do |i|
        ares = [ ]
        @actions.each do |a|
          ares = a.run(i)
        end
        res = res + ares
      end
      return res
    end
  end

  class Sort
    def initialize(xml, rdf_model = nil)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
      parser = Fabulator::XSM::ExpressionParser.new
      @select = (parser.parse(@select, xml) rescue nil)
    end

    def run(context)
      (@select.run(context).first.value rescue '')
    end
  end

  class Considering
    def initialize(xml, rdf_model = nil)
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue rdf_model)
      parser = Fabulator::XSM::ExpressionParser.new
      @select = (parser.parse(@select, xml) rescue nil)
      @actions = ActionLib.compile_actions(xml, rdf_model)
    end

    def run(context)
      c = @select.run(context).first
      res = [ ]
      if(c)
        @actions.each do |action|
          res = action.run(c)
        end
      end
      res
    end
  end

  class While
    def initialize(xml, rdf_model = nil)
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)
      @test = (xml.attributes.get_attribute_ns(FAB_NS, 'test').value rescue '')
      parser = Fabulator::XSM::ExpressionParser.new
      @test = (parser.parse(@test, xml) rescue nil)
      @limit = (xml.attributes.get_attribute_ns(FAB_NS, 'limit').value rescue 1000)
      @actions = ActionLib.compile_actions(xml, rdf_model)
    end

    def run(context)
      res = [ ]
      counter = 0
      while counter < @limit && (@test.run(context).first.value rescue false)
        lres = [ ]
        @actions.each do |action|
          lres = action.run(context)
        end
        res = res + lres
      end
      res
    end
  end
  end
end
