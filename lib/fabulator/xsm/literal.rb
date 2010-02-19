module Fabulator
  module XSM
    class Literal
      def initialize(e)
        @lit = e
      end

      def run(context, autovivify = false)
        return [ context.anon_node(@lit) ]
      end
    end

    class Var
      def initialize(v)
        @var = v
      end

      def run(context, autovivify = false)
        v = context.get_var(@var)
        return [] if v.nil?
        return v.is_a?(Array) ? v : [ v ]
      end
    end
  end
end
