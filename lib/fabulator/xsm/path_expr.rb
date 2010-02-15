module Fabulator
  module XSM
    class PathExpr
      def initialize(pe, predicates, segment)
        @primary_expr = pe
        @predicates = predicates
        @segment = (segment.is_a?(Array) ? segment : [ segment ]) - [nil]
      end

      def run(context, autovivify = false)
        #Rails.logger.info("primary expr: [#{@primary_expr}]")
        #Rails.logger.info("segment: [#{@segment}]")
    
        if @primary_expr.nil?
          possible = [ context ]
        else
          begin
            possible = @primary_expr.run(context,autovivify).uniq
            #Rails.logger.info("Ran primary expr")
          rescue
            #Rails.logger.info("Setting possible to #{context}")
            possible = [ context ]
          end
        end
        #if !@primary_expr
        #  possible = [ context ]
        #else
        #  Rails.logger.info("Running primary expr #{@primary_expr}")
        #  possible = @primary_expr.run(context, autovivify).uniq
        #end

        final = [ ]

        @segment = [ @segment ] unless @segment.is_a?(Array)

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
          pos = [ e ]
          @segment.each do |s|
            #Rails.logger.info("Running segment #{s}")
            pos = pos.collect{ |p| s.run(p, autovivify) }.flatten
          end
            
          final = final + pos
        end

        return final
      end
    end
  end
end
