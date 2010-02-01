module Fabulator
  module XSM
    class Function
      def initialize(ns_map, nom, args)
        bits = nom.split(/:/, 2)
        @ns = ns_map[bits[0]]
        @name = bits[1]
        @args = args
      end

      def run(context, autovivify = false)
        klass = BasicActions.namespaces[@ns]
        a = @args.collect{ |arg| arg.run(context, autovivify) }
        return klass.run_function(@name, a)
      end
    end
  end
end
