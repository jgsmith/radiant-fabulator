module Fabulator
  module XSM
    class Literal
      def initialize(e)
        @lit = e
      end

      def run(context, autovivify = false)
        return [ @lit ]
      end
    end
  end
end
