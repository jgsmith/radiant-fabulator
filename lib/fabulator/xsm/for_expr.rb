module Fabulator
  module XSM
    class ForExpr
      def initialize(v, e)
        if v.size > 1
          @var = v.shift
          @expr = Fabulator::XSM::ForExpr.new(v, e)
        else
          @var = v.first
          @expr = e
        end
      end

      def run(context, autovivify = false)
        result = [ ]
        return result if @var.nil? || @expr.nil?

        @var.each_binding(context, autovivify) do |b|
          result = result + @expr.run(b)
        end
        return result
      end
    end

    class EveryExpr < ForExpr
      def run(context, autovivify = false)
        result = super
        result.each do |r|
          return [ ] unless !!r.value
        end
        return [ context.anon_node(true) ]
      end
    end

    class SomeExpr < ForExpr
      def run(context, autovivify = false)
        result = super
        result.each do |r|
          return [ context.anon_node(true) ] if !!r.value
        end
        return [ ]
      end
    end

    class ForVar
      def initialize(n, e)
        n =~ /^\$?(.*)$/
        @var_name = $1
        @expr = e
      end

      def each_binding(context, autovivify = false, &block)
        context.push_var_ctx
        @expr.run(context, autovivify).each do |e|
          context.set_var(@var_name, e)
          yield context
        end
        context.pop_var_ctx
      end
    end
  end
end
