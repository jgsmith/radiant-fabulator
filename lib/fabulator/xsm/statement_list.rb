module Fabulator
  module XSM
    class StatementList
      def initialize
        @statements = [ ]
      end

      def add_statement(s)
        @statements << s
      end

      def run(context, autovivify = false)
        result = [ ]
        @statements.each do |s| 
          result = s.run(context, autovivify)
        end
        return result
      end
    end
  end
end

