module Fabulator
  module XSM
    class Step
      def initialize(a,n,p)
        @axis = a
        @node_test = n
        @predicate = p
      end

      def run(context)
        c = context
        if !@axis.nil? && @axis != '' && context.roots.has_key?(@axis) &&
            @axis != context.axis
          c = context.roots[@axis]
        end
        if @node_test == '*'
          possible = c.children
        else
          possible = c.children.select{ |cc| cc.name == @node_test }
        end
        # TODO: run predicates
        possible
      end

      def create_node(context)
        return nil if node_text == '*'

        c = Fabulator::XSM::Context.new(context.axis, context.roots, nil, [])
        c.name = @node_test
        context.add_child(c)
        c
      end
    end
  end
end
