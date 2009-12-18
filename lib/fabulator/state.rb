module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class State
    attr_accessor :name, :transitions

    def initialize(xml, rdf_model = nil)
      @name = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
      @rdf_model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue rdf_model)
      @transitions = [ ]
      @pre_actions = [ ]
      @post_actions = [ ]
      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'goes-to':
            @transitions << Transition.new(e, @rdf_model)
          when 'rdf-assert':
            @pre_actions << Assert.new(e, @rdf_model)
          when 'rdf-deny':
            @pre_actions << Deny.new(e, @rdf_model)
          when 'rdf-assertion':
            @post_actions << Assertion.new(e, @rdf_model)
          when 'rdf-denial':
            @post_actions << Denial.new(e, @rdf_model)
          when 'rdf-query':
            @pre_actions << Query.new(e, @rdf_model)
        end
      end
    end

    def states
      @transitions.map { |t| t.state }.uniq
    end

    def select_transition(context,params)
      # we need hypthetical variables here :-/
      best_match = nil
      @transitions.each do |t|
        res = t.validate_params(context,params)
        if res[:missing].empty? && res[:errors].empty? && res[:unknown].empty? && res[:invalid].empty?
          res[:transition] = t
          return res
        end
        if best_match.nil? || res[:score] > best_match[:score]
          best_match = res
          best_match[:transition] = t
        end
      end
      return best_match
    end

    def run_pre(context)
      # do queries, denials, assertions in the order given
      @pre_actions.each do |action|
        if !action.run(context)
          return false
        end
      end
      return true
    end

    def run_post(context)
      # do queries, denials, assertions in the order given
      @post_actions.each do |action|
        if !action.run(context)
          return false
        end
      end
      return true
    end
  end
end
