module Fabulator
  module XSM
    class IfExpr
      def initialize(t, a, b)
        @test = t
        @then_expr = a
        @else_expr = b
      end

      def run(context, autovivify = false)
        res = @test.run(context)

        context.push_var_ctx
        if res.nil? || res.empty? || !res.first.value
          res = @else_expr.nil? ? [] : @else_expr.run(context, autovivify)
        else
          res = @then_expr.run(context, autovivify)
        end
        context.pop_var_ctx
        return res
      end
    end
  end
end
