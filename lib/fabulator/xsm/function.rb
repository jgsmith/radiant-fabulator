module Fabulator
  module XSM
    class Function
      def initialize(ns_map, nom, args)
        bits = nom.split(/:/, 2)
        @ns = ns_map[bits[0]]
        @name = bits[1]
        @args = args
        #Rails.logger.info("Compiled function #{@name}")
      end

      def run(context, autovivify = false)
        klass = ActionLib.namespaces[@ns]
        return [] if klass.nil?
        #Rails.logger.info("Running function #{@name} in #{klass}")
        return klass.run_function(
          context, @name, @args.collect{ |arg| arg.run(context) }
        )
      end
    end
  end
end
