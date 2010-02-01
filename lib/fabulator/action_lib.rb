module Fabulator
  module ActionLib
    mattr_accessor :last_description, :action_descriptions, :namespaces, :function_descriptions
    @@action_descriptions = {}
    @@function_descriptions = {}
    @@namespaces = {}
    
    def self.included(base)
      base.extend(ClassMethods)
      base.module_eval do
        def self.included(new_base)
          super
          new_base.action_descriptions.merge! self.action_descriptions
          new_base.function_descriptions.merge! self.function_descriptions
        end
      end
    end

    def self.compile_actions(xml, rdf_model)
      actions = [ ]
      xml.each_element do |e|
        ns = e.namespaces.namespace.href
        Rails.logger.info("Compiling <#{ns}><#{e.name}>")
        next unless Fabulator::ActionLib.namespaces.include?(ns)
        actions << (Fabulator::ActionLib.namespaces[ns].compile_action(e, rdf_model) rescue nil)
        Rails.logger.info("compile_actions: #{actions}")
      end
      Rails.logger.info("compile_actions: #{actions}")
      actions = actions - [ nil ]
      Rails.logger.info("compile_actions returning: #{actions}")
      return actions
    end
    
    def compile_action(e, r)
      send "action:#{e.name}", e, r
    end

    def run_function(nom, args)
      send "fctn:#{nom}", args
    end

    def action_descriptions(hash=nil)
      self.class.action_descriptions hash
    end

    def function_descriptions(hash=nil)
      self.class.function_descriptions hash
    end
  
    module ClassMethods
      def inherited(subclass)
        subclass.action_descriptions.reverse_merge! self.action_descriptions
        super
      end
      
      def action_descriptions(hash = nil)
        Fabulator::ActionLib.action_descriptions[self.name] ||= (hash ||{})
      end
    
      def register_namespace(ns)
        Fabulator::ActionLib.namespaces[ns] = self.new
      end

      def namespaces
        Fabulator::ActionLib.namespaces
      end
  
      def desc(text)
        Fabulator::ActionLib.last_description = RedCloth.new(Util.strip_leading_whitespace(text)).to_html
      end
      
      def action(name, klass = nil, &block)
        self.action_descriptions[name] = Fabulator::ActionLib.last_description if Fabulator::ActionLib.last_description
        Fabulator::ActionLib.last_description = nil
        if block
          define_method("action:#{name}", &block)
        elsif !klass.nil?
          action(name) { |e,r|
            return klass.new(e,r)
          }
        end
      end

      def function(name, &block)
        self.function_descriptions[name] = Fabulator::ActionLib.last_description if Fabulator::ActionLib.last_description
        Fabulator::ActionLib.last_description = nil
        define_method("fctn:#{name}", &block)
      end

      def compile_actions(xml, rdf_model)
        actions = [ ]
        xml.each_element do |e|
          ns = e.namespaces.namespace.href
          Rails.logger.info("Compiling <#{ns}><#{e.name}>")
          next unless Fabulator::ActionLib.namespaces.include?(ns)
          actions << (Fabulator::ActionLib.namespaces[ns].compile_action(e, rdf_model) rescue nil)
          Rails.logger.info("compile_actions: #{actions}")
        end
        Rails.logger.info("compile_actions: #{actions}")
        actions = actions - [ nil ]
        Rails.logger.info("compile_actions returning: #{actions}")
        return actions
      end
  
    end
     
    module Util
      def self.strip_leading_whitespace(text)
        text = text.dup
        text.gsub!("\t", "  ")
        lines = text.split("\n")
        leading = lines.map do |line|
          unless line =~ /^\s*$/
             line.match(/^(\s*)/)[0].length
          else
            nil
          end
        end.compact.min
        lines.inject([]) {|ary, line| ary << line.sub(/^[ ]{#{leading}}/, "")}.join("\n")
      end      
    end
  end
end
