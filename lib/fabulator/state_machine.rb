module Fabulator
  FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  class StateMachine
    attr_accessor :states

    def initialize(xml,logger = nil)
      # /statemachine/states
      @states = { }
      @queries = [ ]
      @assert_deny = [ ]
      @default_model = xml.root.attributes.get_attribute_ns(FAB_NS,'rdf-model').value rescue nil
      xml.root.each_element do |child|
        next unless child.namespaces.namespace.href == FAB_NS
        case child.name
          when 'view':
            cs = State.new(child)
            @states[cs.name] = cs
          when 'rdf-query':
            @queries << Query.new(child, @default_model)
          when 'rdf-assert':
            @assert_deny << Assert.new(child, @default_model)
          when 'rdf-deny':
            @assert_deny << Deny.new(child, @default_model)
        end
      end
    end

    def context
      if @context.nil? || @context.empty?
        # we need to initialize ourselves
        @context = { :state => 'start', :data => { } }
        @queries.each do |q|
          p = (q.as || '').split('/')
          t = @context[:data]
          last_p = p.pop
          p.each do |c|
            t[c] = { } if t[c].nil?
            t = t[c]
          end
          t[last_p] = q.run
        end
        @assert_deny.each do |ad|
          if !ad.run
            @context[:state] = ad.state
            break
          end
        end
      end
      @context
    end

    def context=(c)
      @context = c
    end

    def run(params)
      Rails.logger.info('Running statemachine')
      Rails.logger.info("Params: #{YAML::dump(params)}")
      c = self.context
      current_state = @states[c[:state]]
      Rails.logger.info("Current state: [#{current_state}]")
      if !current_state.blank?
        # select transition
        # possible get some errors
        # run transition, and move to new state as needed
        best_transition = current_state.select_transition(params)
        Rails.logger.info("Best transition: #{YAML::dump(best_transition)}")
        t = best_transition[:transition]
        c[:state] = t.state
        # merge valid and context
        c[:data].merge!(best_transition[:valid])
        t.run(c[:data])
      end
    end

    def state
      self.context[:state]
    end

    def state_names
      (@states.keys.map{ |k| @states[k].states }.flatten + @states.keys).uniq
    end
  end
end
