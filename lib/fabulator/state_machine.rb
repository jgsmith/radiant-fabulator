module Fabulator
  FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  RDFS_NS = 'http://www.w3.org/2000/01/rdf-schema#'
  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  RDFA_NS = 'http://dh.tamu.edu/ns/fabulator/rdf/1.0#'
  class StateChangeException < Exception
  end

  class StateMachine
    attr_accessor :states, :missing_params, :errors, :namespaces, :updated_at

    def initialize(xml)
      # /statemachine/states
      @states = { }
      self.namespaces = { }
      @default_model = xml.root.attributes.get_attribute_ns(FAB_NS,'rdf-model').value rescue nil
      @actions = ActionLib.compile_actions(xml.root, @default_model)
      Rails.logger.info("Actions: #{@actions}")
      xml.root.each_element do |child|
        next unless child.namespaces.namespace.href == FAB_NS
        case child.name
          when 'view':
            cs = State.new(child, @default_model)
            @states[cs.name] = cs
        end
      end

      xml.root.namespaces.each do |ns|
        self.namespaces[ns.prefix] = ns.href
      end
      begin
        self.namespaces[''] = xml.root.namespaces.default.href
      rescue
      end
      Rails.logger.info("Namespaces: #{YAML::dump(self.namespaces)}")
    end

    def namespaces 
      Rails.logger.info("Returning namespaces: #{@namespaces}")
      @namespaces
    end

    def init_context(c)
      if @context.nil? || @context.empty?
        # we need to initialize ourselves
        @context = Fabulator::Context.new
      end
      @context.data = c
      Rails.logger.info("Init_Context(#{c})")
      begin
        @actions.each do |q|
          Rails.logger.info("Running #{q}")
          q.run(c)
        end
      rescue Fabulator::StateChangeException => e
        @context.state = e
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
        @errors = best_transition[:messages]
        if @missing_params.empty? && @errors.empty?
          c.state = t.state
          # merge valid and context
          Rails.logger.info("Best transition: #{YAML::dump(best_transition)}")
          best_transition[:valid].each do |item|
            p = item.path.gsub(/^[^:]+::/, '').split('/') - [ '' ]
            Rails.logger.info("Adding #{item.path} at /#{p.join('/')}")
            n = c.data.traverse_path(p, true).first
            n.prune
            n.copy(item)
            #c.data.traverse_path(p, true).copy(item)
          end
          Rails.logger.info("Resulting data: #{YAML::dump(c.data)}")
          #c.merge!(best_transition[:valid])
          # run_post of state we're leaving
          begin
            current_state.run_post(c.data)
            t.run(c.data)
            # run_pre for the sate we're going to
            new_state = @states[c.state]
            new_state.run_pre(c.data) if !new_state.nil?
          rescue Fabulator::StateChangeException => e # catch state change
            new_state = @states[e]
            begin
              if !new_state.nil?
                c.state = new_state.name
                new_state.run_pre(c.data)
              end
            rescue Fabulator::StateChangeException => e
              new_state = @states[e] 
              retry
            end
          end
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
