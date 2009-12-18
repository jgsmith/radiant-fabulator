module Fabulator
  module XSM
    class PathExpr
      def initialize(pe, predicates, segment)
        @primary_expr = pe
        @predicates = predicates
        @segment = segment
      end

      def run(context)
        if @primary_expr.nil? && !@segment.nil?
          possible = [ context ]
        else
          possible = @primary_expr.run(context).uniq
        end

        final = [ ]

        possible.each do |e|
          next if e.nil?
          not_pass = false
          @predicates.each do |p|
            if !p.test(e)
              not_pass = true
              break
            end
          end
          next if not_pass
          final = final + e.traverse_path(@segment)
        end
        return final.uniq
      end
    end
  end
end
