module Fabulator
  module XSM
    class LetExpr
      def initialize(dqname, expr)
        @expr = expr
        dqname =~ /^\$?(.*)$/
        @name = $1
      end

      def run(context, autovivify = false)
        result = @expr.run(context, autovivify)
        context.set_var(@name, result)
        return [ ]
      end
    end

    class Var
      def initialize(dqname)
        dqname =~ /^$(.*)$/
        @name = $1
      end

      def run(context, autovivify = false)
        return [ context.get_var(@name) ]
      end
    end
  end
end
