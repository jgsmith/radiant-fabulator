module Fabulator
  module Core
  class Filter
    def compile_xml(xml, c_attrs = { })
      #@filter_type = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
      @filter_type = ActionLib.get_local_attr(xml, FAB_NS, 'name')
      self
    end

    def run(context)
      # do special ones first
      items = context.is_a?(Array) ? context : [ context ]
      filtered = [ ]
      case @filter_type.run(items.first).first.value
        when 'trim':
          items.each do |c|
            v = c.value
            v.chomp!
            v.gsub!(/^\s*/,'')
            v.gsub!(/\s*$/,'')
            c.value = v
            filtered << c.path
          end
        when 'downcase':
          items.each do |c|
            v = c.value
            v.downcase!
            c.value = v
            filtered << c.path
          end
        when 'upcase':
          items.each do |c|
            v = c.value
            v.upcase!
            c.value = v
            filtered << c.path
          end
        when 'integer':
          items.each do |c|
            v = c.value
            v = v.to_i.to_s
            c.value = v
            filtered << c.path
          end
        when 'decimal':
          items.each do |c|
            v = c.value
            v = v.to_f.to_s
            c.value = v
            filtered << c.path
          end
        else
          # TODO: Decouple Fabulator from Radiant extension
          f = FabulatorFilter.find_by_name(@type) rescue nil
          items.each do |c|
            f.run(context) unless f.nil?
            filtered << c.path
          end
      end
      return filtered
    end
  end
  end
end
