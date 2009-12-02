module Fabulator
  FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  RDFS_NS = 'http://www.w3.org/2000/01/rdf-schema#'
  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  class StateMachine
    attr_accessor :states

    def initialize(xml,logger = nil)
      # /statemachine/states
      @states = { }
      @actions = [ ]
      @default_model = xml.root.attributes.get_attribute_ns(FAB_NS,'rdf-model').value rescue nil
      xml.root.each_element do |child|
        next unless child.namespaces.namespace.href == FAB_NS
        case child.name
          when 'view':
            cs = State.new(child, @default_model)
            @states[cs.name] = cs
          when 'rdf-query':
            @actions << Query.new(child, @default_model)
          when 'rdf-assert':
            @actions << Assert.new(child, @default_model)
          when 'rdf-deny':
            @actions << Deny.new(child, @default_model)
        end
      end
    end

    def context
      if @context.nil? || @context.empty?
        # we need to initialize ourselves
        @context = Fabulator::Context.new
        @actions.each do |q|
          Rails.logger.info("Running action #{YAML::dump(q)}")
          if !q.run(@context)
            break
          end
        end
      end
      @context
    end

    def context=(c)
      if c.is_a?(Hash)
        @context = Fabulator::Context.new
        @context.context = c
      else
        @context = c
      end
    end

    def run(params)
      Rails.logger.info('Running statemachine')
      Rails.logger.info("Params: #{YAML::dump(params)}")
      c = self.context
      current_state = @states[c.state]
      Rails.logger.info("Current state: [#{current_state}]")
      if !current_state.blank?
        # select transition
        # possible get some errors
        # run transition, and move to new state as needed
        best_transition = current_state.select_transition(c,params)
        Rails.logger.info("Best transition: #{YAML::dump(best_transition)}")
        t = best_transition[:transition]
        c.state = t.state
        # merge valid and context
        c.merge!(best_transition[:valid])
        t.run(c)
      end
    end

    def state
      self.context.state
    end

    def data
      self.context.data
    end

    def state_names
      (@states.keys.map{ |k| @states[k].states }.flatten + @states.keys).uniq
    end
  end
end
