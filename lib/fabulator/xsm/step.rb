module Fabulator
  module XSM
    class Step
      def initialize(a,n)
        @axis = a
        @node_test = n
      end

      def run(context, autovivify = false)
        c = context
        #Rails.logger.info("Step #{context} : #{@node_test}")
        if !@axis.nil? && @axis != '' && context.roots.has_key?(@axis) &&
            @axis != context.axis
          c = context.roots[@axis]
        end
        if @node_test.is_a?(String)
          n = @node_test
        else
          n = (@node_test.run(context).last.value rescue nil)
        end 
        return [ ] if n.nil?
        if n == '*'
          possible = c.children
        else
          possible = c.children.select{ |cc| cc.name == n }
          if possible.empty? && autovivify
            #Rails.logger.info("Autovivifying #{n}")
            possible = c.traverse_path([ n ], true)
          end
        end
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
