module Fabulator
  module XSM
    class BinExpr
      def initialize(left, right)
        @left = left
        @right = right
      end

      def run(context, autovivify = false)
        l = @left.run(context, autovivify)
        r = @right.run(context, autovivify)

        l = [ l ] unless l.is_a?(Array)
        r = [ r ] unless l.is_a?(Array)

        l = l.collect { |i| i.value }.uniq - [ nil ]
        r = r.collect { |i| i.value }.uniq - [ nil ]

        res = []

        l.each do |i|
          r.each do |j|
            res << Fabulator::XSM::Context.new(
              context.axis,
              context.roots,
              self.calculate(i,j),
              []
            )
          end
        end
        return res
      end

    end

    class AddExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a+b
      end
    end

    class SubExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a-b
      end
    end

    class LtExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a < b
      end
    end

    class LteExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a <= b
      end
    end

    class EqExpr < BinExpr
      def calculate(a,b)
        a == b
      end
    end

    class NeqExpr < BinExpr
      def calculate(a,b)
        a != b
      end
    end

    class MpyExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a*b
      end
    end

    class DivExpr < BinExpr
      def calculate(a,b)
        return nil if b.nil? || a.nil? || ( b >= 0 && b <= 0)
        a/b
      end
    end

    class ModExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        a % b
      end
    end

    class RangeExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        if a < b
          a .. b
        else
          (b .. a).reverse
        end
      end
    end
  end
end
