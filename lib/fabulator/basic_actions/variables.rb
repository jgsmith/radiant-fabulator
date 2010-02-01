module Fabulator
  module BasicActions
  class ValueOf
    def initialize(xml, rdf_model = nil)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
      parser = Fabulator::XSM::ExpressionParser
      @select = parser.parse(@select, xml)
    end

    def run(context, autovivify = false)
      @select.run(context)
    end
  end

  class Value
    def initialize(xml, rdf_model = nil)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
      Rails.logger.info("value select: [#{@select}]")
      parser = Fabulator::XSM::ExpressionParser.new
      @select = (parser.parse(@select, xml) rescue nil)
      Rails.logger.info("value compiled select: #{YAML::dump(@select)}")
      @name = (xml.attributes.get_attribute_ns(FAB_NS, 'path').value rescue '')
      Rails.logger.info("value path: [#{@name}]")
      @name = parser.parse(@name, xml)
      Rails.logger.info("value compiled path: #{YAML::dump(@name)}")
      @actions = BasicActions.compile_actions(xml, rdf_model)
    end

    def run(context, autovivify = false)
      return [] if @name.nil?
      Rails.logger.info("Running @name...")
      tgt = @name.run(context, true).first
      Rails.logger.info("Finished Running @name... [#{tgt.path}]")
      src = nil
      if @select.nil?
        @actions.each do |action|
          src = action.run(context)
          Rails.logger.info("size of src from #{action}: #{src.nil? ? 0 : src.size}")
        end
      else
        src = @select.run(context)
      end
      Rails.logger.info("\n\n\nsize of src: #{src.nil? ? 0 : src.size}\n\n\n")
      tgt.prune
      ret = [ ]
      if src.nil? || src.empty?
        tgt.value = nil
        ret << tgt
      elsif src.size == 1
        tgt.copy(src.first)
        Rails.logger.info("Adding #{src.first.path} to #{tgt.path}")
        ret << tgt
      else
        p = tgt.parent
        nom = tgt.name
        p.prune(p.children(nom))
        src.each do |s|
          tgt = p.create_child(nom,nil)
          Rails.logger.info("Adding #{s.path} to #{tgt.path}")
          tgt.copy(s)
          ret << tgt
        end
      end
      ret
    end
  end

  class Variable
    def initialize(xml, rdf_model = nil)
      @select = (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
      parser= Fabulator::XSM::ExpressionParser
      @select = (parser.parse(@select, xml) rescue nil)
      @name = (xml.attributes.get_attribute_ns(FAB_NS, 'name').value rescue nil)
      @actions = BasicActions.compile_actions(xml, rdf_model)
    end

    def run(context)
      return [] if @name.nil?
      res = [ ]
      if @select
        res = @select.run(context)
      elsif !@actions.empty?
        @actions.each do |a|
          res = a.run(context)
        end
      end
      context.set_var(@name, res)
      res
    end
  end
  end
end
