module Fabulator
  module XSM
    class Literal
      def initialize(e)
        @lit = e
      end

      def run(context, autovivify = false)
        return [
          Fabulator::XSM::Context.new('data', context.roots, @lit, [])
        ]
      end
    end
  end
end
