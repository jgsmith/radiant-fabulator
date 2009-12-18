module Fabulator
  module XSM
    class AxisDescendentOrSelf
      def initialize(step = nil)
        @step = step
      end

      def run(context)
        if context.is_a?(Array)
          stack = context
        else
          stack = [ context ]
        end
        possible = [ ]
        while !stack.empty?
          c = stack.shift

          stack = stack + c.children

          possible = possible + c.run(@step)
        end
        return possible.uniq
      end
    end
  end
end
