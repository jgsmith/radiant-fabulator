module Fabulator
  module Core
  module Actions
  class ForEach
    def compile_xml(xml, c_attrs = {})
      @select = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true })
      @sort = [ ]

      @as = (xml.attributes.get_attribute_ns(FAB_NS, 'as').value rescue nil)

      @actions = ActionLib.compile_actions(xml, c_attrs)

      attrs = ActionLib.collect_attributes(c_attrs, xml)

      xml.each_element do |e|
        next unless e.namespaces.namespace.href == FAB_NS
        case e.name
          when 'sort-by':
            @sort << Sort.new.compile_xml(e, attrs)
        end
      end
      self
    end

    def run(context)
      items = @select.run(context)
      context.push_var_ctx
      if !@sort.empty?
        items = items.sort_by{ |i| 
          context.set_var(@as, i) unless @as.nil? 
          @sort.collect{|s| s.run(i) }.join("\0") 
        }
      end
      res = [ ]
      items.each do |i|
        ares = [ ]
        context.set_var(@as, i) unless @as.nil?
        @actions.each do |a|
          ares = a.run(i)
        end
        res = res + ares
      end
      context.pop_var_ctx
      return res
    end
  end

  class Sort
    def compile_xml(xml, c_attrs = {})
      @select = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true })
      self
    end

    def run(context)
      (@select.run(context).first.value.to_s rescue '')
    end
  end

  class Considering
    def compile_xml(xml, c_attrs = {})
      @select = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true })
      @as = (xml.attributes.get_attribute_ns(FAB_NS, 'as').value rescue nil)
      @actions = ActionLib.compile_actions(xml, c_attrs)
      self
    end

    def run(context)
      return [] if @select.nil?
      c = @select.run(context)
      res = [ ]
      root = nil
      if @as.nil?
        if c.size == 1
          root = c.first
        else
          root = Fabulator::XSM::Context.new('data', context.roots, nil, c)
        end
      else
        root = context
        root.push_var_ctx
        root.set_var(@as, c)
      end
      @actions.each do |action|
        res = action.run(root)
      end
      if !@as.nil?
        root.pop_var_ctx
      end
      res
    end
  end

  class While
    def compile_xml(xml, c_attrs = {})
      @test = ActionLib.get_local_attr(xml, FAB_NS, 'test', { :eval => true })
      @limit = ActionLib.get_local_attr(xml, FAB_NS, 'limit', { :default => 1000 })
      @actions = ActionLib.compile_actions(xml, c_attrs)
      self
    end

    def run(context)
      res = [ ]
      counter = 0
      lim = @limit.nil? ? 1000 : @limit.run(context).first.value
      while counter < @limit && (!!@test.run(context).first.value rescue false)
        lres = [ ]
        @actions.each do |action|
          lres = action.run(context)
        end
        res = res + lres
      end
      res
    end
  end
  end
  end
end
