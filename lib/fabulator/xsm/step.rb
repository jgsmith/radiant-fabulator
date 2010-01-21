module Fabulator
  module XSM
    class Step
      def initialize(a,n)
        @axis = a
        @node_test = n
      end

      def run(context)
        c = context
        if !@axis.nil? && @axis != '' && context.roots.has_key?(@axis) &&
            @axis != context.axis
          c = context.roots[@axis]
        end
        Rails.logger.info("Looking for #{@node_test} under #{c.path}")
        if @node_test == '*'
          possible = c.children
        else
          possible = c.children.select{ |cc| cc.name == @node_test }
        end
        Rails.logger.info("Found #{possible.size} children")
        return possible
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
