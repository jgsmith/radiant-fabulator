module Fabulator
  module XSM
    class Predicates
      def initialize(expr,p)
        @expr = expr
        @predicates = p
      end

      def run(context)
        # we want to run through all of the predicates and return true if
        # they all return true
        result = [ ]
        @expr.run(context).each do |c|
          @predicates.each do |p|
            res = p.run(context)
            if res.is_a?(Array)
              result << c unless res.empty?
            else
              result << c if !!res
            end
          end
        end
        return result
      end
    end
  end
end