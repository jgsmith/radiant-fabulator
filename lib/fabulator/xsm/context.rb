module Fabulator
  module XSM
    class Context
      attr_accessor :axis, :value, :name, :roots

      def initialize(a,r,v,c,p = nil)
        @roots = r
        @axis = a
        @children = c
        @value = v
        @parent = p
        @name = nil
      end

      def create_child(n,v = nil)
        node = self.class.new(@axis, @roots, v, [], self)
        node.name = n
        @children << node
        node
      end

      def empty?
        @value.nil? && @children.empty?
      end

      def merge_data(d,p = nil)
        # we have a hash or array based on root (r)
        if p.nil?
          root_context = [ self ]
        else
          root_context = self.traverse_path(p,true)
        end
        if root_context.size > 1
          raise "Unable to merge data into multiple places simultaneously"
        else
          root_context = root_context.first
        end
        if d.is_a?(Array)
          node_name = root_context.name
          root_context = root_context.parent
          d.each do |i|
            c = root_context.create_child(node_name)
            c.merge_data(i)
          end
        elsif d.is_a?(Hash)
          d.each_pair do |k,v|
            if k =~ /\./
              bits = k.split('.')
              ln = bits.pop
              c = root_context.traverse_path(bits,true).first
              c = c.create_child(ln)
            else
              c = root_context.create_child(k)
            end
            if v.is_a?(Hash) || v.is_a?(Array)
              c.merge_data(v)
            else
              c.value = v
            end
          end
        else
          c = root_context.parent.create_child(root_context.name, d)
        end
      end

      def eval_expression(selection)
        if selection.is_a?(String)
          p = Fabulator::XSM::ExpressionParser.new
          selection = p.parse(selection)
        end

        if selection.nil?
          return self.class.new(@axis, @roots, @value, [], @roots[@axis])
        end

        # run selection against current context
        selection.run(self)
      end

      def traverse_path(path, autovivify = false)
        return self if path.nil? || path.empty?

        current = [ self ]

        path.each do |c|
          set = [ ]
          current.each do |cc|
            if c.is_a?(String)
              cset = cc.children.select{|c3| c3.name == c }
            else
              cset = c.run(cc)
            end
            if cset.nil? || cset.empty?
              if autovivify
                if c.is_a?(String)
                  cset = [ cc.create_child(c) ]
                else
                  cset = [ c.create_node(cc) ]
                end
              end
            end
            set = set + cset
          end
          current = set
        end
        return current
      end

      def parent=(p)
        @parent = p
        @axis = p.axis
      end

      def parent
        @parent.nil? ? self : @parent
      end

      def children
        @children
      end

      def get_values(ln = nil)
        return [] if ln.nil?
        self.children.select{|c| c.name == ln}.collect{|c| c.value } - [nil]
      end

      def root(a = nil)
        @roots[a.nil? ? @axis : a]
      end

      def add_child(c)
        c.parent = self
        @current << c
      end
    end

    class CurrentContext
      def initialize
      end

      def run(context)
        context.nil? ? [] : [ context ]
      end

      def create_node(context)
        context
      end
    end

    class RootContext
      def initialize(axis = nil)
        @axis = axis
      end

      def run(context)
        c = context.root(@axis)
        return [ ] if c.nil?
        return [ c ]
      end

      def create_node(context)
        if context.root(@axis).nil?
          context.roots[@axis] = Fabulator::XSM::Context.new(@axis,context.roots,nil,[])
        end
        context.root(@axis)
      end
    end
  end
end
