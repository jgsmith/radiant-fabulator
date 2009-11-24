module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'

  class Filter
    def initialize(xml)
      @filter_type = xml.attributes.get_attribute_ns(FAB_NS, 'type').value
    end

    def apply_filter(params, fields)
      # do special ones first
      Rails.logger.info("Filter(#{@filter_type}, #{fields.join(", ")})")
      case @filter_type
        when 'trim':
          fields.each do |f|
            params[f].chomp!
            params[f].gsub!(/^\s*/,'')
            params[f].gsub!(/\s*$/,'')
          end
        when 'downcase':
          fields.each do |f|
            params[f].downcase!
          end
        when 'upcase':
          fields.each do |f|
            params[f].upcase!
          end
        when 'integer':
          fields.each do |f|
            params[f] = params[f].to_i.to_s
          end
        when 'decimal':
          fields.each do |f|
            params[f] = params[f].to_f.to_s
          end
        else
          f = FabulatorFilter.find_by_name(@type) rescue nil
          return if f.nil?
          f.run_filter(params, fields)
      end
    end
  end
end
