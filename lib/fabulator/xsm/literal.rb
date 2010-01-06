module Fabulator
  module XSM
    class Literal
      def initialize(e)
        @lit = e
      end

      def run(context)
        return [ @lit ]
      end
    end
  end
end
