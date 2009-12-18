module Fabulator
  module XSM
    class AxisParent
      def run(context)
        if context.is_a?(Array)
          context.collect { |c| c.parent }.uniq
        else
          context.parent
        end
      end
    end
  end
end
