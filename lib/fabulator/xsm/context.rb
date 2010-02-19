module Fabulator
  module XSM
    class Context
      attr_accessor :axis, :value, :name, :roots

      def initialize(a,r,v,c,p = nil,f={})
        @roots = r
        @axis = a
        @children = []
        @children = @children + c if c.is_a?(Array)
        @value = v
        @parent = p
        @name = nil
        @e_ctx = f
      end

      def to_s
        self.value.to_s
      end

      def anon_node(v)
        return self.class.new(self.axis, self.roots, v, [])
      end

      def ctx
        return parent.ctx if @parent && @parent != self
        return @e_ctx
      end

      def set_var(n,v)
        return @roots['data'].set_var(n,v) if @roots['data'] != self
        if n =~ /^\$?(.*)$/
          @e_ctx[:vars] ||= [ ]
          @e_ctx[:vars][0] ||= { }
          @e_ctx[:vars][0][$1] = v
        end
      end

      def get_var(n)
        return parent.get_var(n,v) if @parent && @parent != self
        @e_ctx[:vars] ||= [ ]
        @e_ctx[:vars].each do |vs|
          return vs[n] if vs.has_key?(n)
        end
        return nil
      end

      def push_var_ctx
        return parent.push_var_ctx if @parent && @parent != self
        @e_ctx[:vars] ||= [ ]
        @e_ctx[:vars].unshift { }
      end

      def pop_var_ctx
        return parent.pop_var_ctx if @parent && @parent != self
        @e_ctx[:vars] ||= [ ]
        @e_ctx[:vars].shift
      end

      def copy(c)
        @value = c.value
        c.children.each do |cc|
          pos = self.children(cc.name)
          if pos.size == 1
            pos.first.copy(cc)
          else
            n = self.create_child(cc.name, cc.value)
            n.copy(cc)
          end
        end
      end

      def clone()
        node = self.class.new(@axis, @roots, self.value, [], nil)
        node.name = self.name
        node
      end

      def create_child(n,v = nil)
        node = self.class.new(@axis, @roots, v, [], self)
        node.name = n
        @children << node
        node
      end

      def path
        if self.parent.nil? || self.parent == self
          return @axis + '::'
        else
          return self.parent.path + '/' + @name
        end
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
          # see if we need to prune
          new_rc = [ ]
          root_context.each do |c|
            if c.children.size == 0 && c.value.nil?
              c.parent.prune(c) if c.parent
            else
              new_rc << c
            end
          end
          if new_rc.size > 0
            raise "Unable to merge data into multiple places simultaneously"
          else
            root_context = new_rc
          end
        else
          root_context = root_context.first
        end
        #Rails.logger.info("Merge Path: #{root_context.path}")
        #Rails.logger.info("Merging into #{root_context.path rescue '*'}: #{YAML::dump(d)}")
        if d.is_a?(Array)
          node_name = root_context.name
          root_context = root_context.parent
          #Rails.logger.info("Array context: #{root_context.path} / #{node_name}")
          # get rid of empty children so we don't have problems later
          root_context.children.each do |c|
            if c.children.size == 0 && c.name == node_name && c.value.nil?
              c.parent.prune(c)
            end
          end
          d.each do |i|
            c = root_context.create_child(node_name)
            c.merge_data(i)
          end
        elsif d.is_a?(Hash)
          d.each_pair do |k,v|
            #Rails.logger.info("Merging [#{k}]")
            bits = k.split('.')
            c = root_context.traverse_path(bits,true).first
            #Rails.logger.info("Possibly created path: #{c.path}")
            if v.is_a?(Hash) || v.is_a?(Array)
              c.merge_data(v)
            else
              #Rails.logger.info("Set value: #{c.path} == #{v}")
              c.value = v
            end
          end
        else
          c = root_context.parent.create_child(root_context.name, d)
        end
      end

      def eval_expression(selection, ns = { })
        self.push_var_ctx
        if selection.is_a?(String)
          p = Fabulator::XSM::ExpressionParser.new
          selection = p.parse(selection, ns)
          #Rails.logger.info("Parsed selection: #{YAML::dump(selection)}")
        end

        if selection.nil?
          res = self.class.new(@axis, @roots, @value, [], @roots[@axis])
        else
          # run selection against current context
          res = selection.run(self)
        end
        self.pop_var_ctx
        return res
      end

      def traverse_path(path, autovivify = false)
        #Rails.logger.info("path: [#{path}]")
        return [ self ] if path.nil? || path.is_a?(Array) && path.empty?

        path = [ path ] unless path.is_a?(Array)

        current = [ self ]

        path.each do |c|
          set = [ ]
          current.each do |cc|
            if c.is_a?(String)
              cset = cc.children.select{|c3| c3.name == c }
            else
              #Rails.logger.info("running: [#{c}]")
              cc.push_var_ctx
              cset = c.run(cc)
              cc.pop_var_ctx
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

      def children(n = nil)
        if n.nil?
          @children
        else
          @children.select{|c| c.name == n }
        end
      end

      def prune(c = nil)
        if c.nil?
          @children = [ ]
        else
          @children = @children - [ c ]
        end
      end

      def get_values(ln = nil)
        return [] if ln.nil?
        self.children.select{|c| c.name == ln}.collect{|c| c.value } - [nil]
      end

      def root(a = nil)
        if(a.nil? || a == '')
          a = @axis
        end
        if a.nil? || a == '' || @roots[a].nil?
          p = self
          while !p.parent.nil? && p.parent != self
            p = p.parent
          end
          return p
        else
          @roots[a.nil? ? @axis : a]
        end
      end

      def add_child(c)
        c.parent.prune(c) if c.parent
        c.parent = self
        c.axis = self.axis
        @children << c
      end
    end

    class CurrentContext
      def initialize
      end

      def run(context, autovivify = false)
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

      def run(context, autovivify = false)
        c = context.root(@axis)
        #Rails.logger.info("RootContext.run() - axis=[#{@axis}]")
        #Rails.logger.info("     c: [#{c}]")
        #Rails.logger.info("   children of c: [#{c.children.collect{|cc| cc.name}.join(", ")}]")
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
