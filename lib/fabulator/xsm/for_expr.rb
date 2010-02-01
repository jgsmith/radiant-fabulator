module Fabulator
  module XSM
    class ForExpr
      def initialize(v, e)
        if v.size > 1
          @var = v.shift
          @expr = Fabulator::XSM::ForExpr.new(v, e)
        else
          @var = v
          @expr = e
        end
      end

      def run(context, autovivify = false)
        result = [ ]
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
          return [ ] unless r
        end
        return [ true ]
      end
    end

    class SomeExpr < ForExpr
      def run(context, autovivify = false)
        result = super
        result.each do |r|
          return [ true ] if r
        end
        return [ ]
      end
    end

    class ForVar
      def initialize(n, e)
        n =~ /\$(.*)/
        @var_name = $1
        @expr = e
      end

      def each_binding(context, autovivify = false, &block)
        @expr.run(context, autovivify).each do |e|
          cc = context.clone_vars
          cc.set_var(@var_name, e)
          yield cc
        end
      end
    end
  end
end
