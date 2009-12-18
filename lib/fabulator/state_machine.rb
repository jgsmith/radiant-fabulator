module Fabulator
  FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  RDFS_NS = 'http://www.w3.org/2000/01/rdf-schema#'
  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  class StateMachine
    attr_accessor :states, :missing_params, :errors

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

    def init_context(c)
      if @context.nil? || @context.empty?
        # we need to initialize ourselves
        @context = Fabulator::Context.new
      end
      @context.data = c
      @actions.each do |q|
        if !q.run(@context)
          return
        end
      end
    end

    def context
      @context
    end

    def context=(c)
      if c.is_a?(Fabulator::XSM::Context)
        @context ||= Fabulator::Context.new
        @context.context = { :state => @context.state, :data => c }
      elsif c.is_a?(Hash)
        @context = Fabulator::Context.new
        @context.state = c[:state]
        @context.data = c[:data]
      else
        @context = c
      end
    end

    def run(params)
      c = self.context
      current_state = @states[c.state]
      if !current_state.blank?
        # select transition
        # possible get some errors
        # run transition, and move to new state as needed
        best_transition = current_state.select_transition(c,params)
        t = best_transition[:transition]
        @missing_params = best_transition[:missing]
        @errors = best_transition[:errors]
        if @missing_params.empty? && @errors.empty?
          c.state = t.state
          # merge valid and context
          c.merge!(best_transition[:valid])
          # run_post of state we're leaving
          current_state.run_post(c)
          t.run(c)
          # run_pre for the sate we're going to
          new_state = @states[c.state]
          new_state.run_pre(c) if !new_state.nil?
        end
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
