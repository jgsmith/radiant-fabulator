module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class Filter
    def initialize(xml)
      @filter_type = xml.attributes.get_attribute_ns(FAB_NS, 'name').value
    end

    def run(context)
      # do special ones first
      items = context.is_a?(Array) ? context : [ context ]
      filtered = [ ]
      case @filter_type
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
