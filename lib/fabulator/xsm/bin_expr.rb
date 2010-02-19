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
            calc = self.calculate(i,j)
            if !calc.is_a?(Array)
              calc = [ calc ]
            end

            res = res + calc.collect { |c| context.anon_node(c) }
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
        a.to_s == b.to_s
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
        r = a.to_f*b.to_f
        return r.to_i if r % 1.0 == 0.0
        return r
      end
    end

    class DivExpr < BinExpr
      def calculate(a,b)
        return nil if b.nil? || a.nil? || ( b >= 0 && b <= 0)
        r = a.to_f/b.to_f
        r = r.to_i if r % 1.0 == 0.0
        r
      end
    end

    class ModExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        r = a.to_f % b.to_f
        r = r.to_i if r % 1.0 == 0.0
        r
      end
    end

    class RangeExpr < BinExpr
      def calculate(a,b)
        return nil if a.nil? || b.nil?
        if a < b
          r = (a.to_i .. b.to_i).to_a
        else
          r = (b.to_i .. a.to_i).to_a.reverse
        end
        return r
      end
    end
  end
end
