module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  class Query
    attr_accessor :as

    def initialize(xml, def_model = nil)
      @model = xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model
      @as    = xml.attributes.get_attribute_ns(FAB_NS, 'as').value.split(/\//) rescue []
      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end
    end

    def run(context)
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model ])
      return true if rdf_model.nil?

      results = [ ]
      @sql.each do |s|
        Rails.logger.info(YAML::dump(s))
        conditions = [ s[:simple_where] ]
        s[:where_params].each do |p|
          if p == :model
            conditions << rdf_model.id
          elsif p.is_a?(Array)
            case p[0]
              when :literal:
                conditions << (RdfLiteral.first(:conditions => [ 'obj_lit = ?', p[1] ]).id rescue 0)
              when :resource:
                conditions << (RdfResource.from_uri(p[1]) rescue 0)
              when :namespace:
                conditions << (RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0)
            end
          end
        end
        results = results + RdfQueryResult.find_by_sql(%{
          SELECT DISTINCT #{s[:select]}
          FROM #{s[:from]}
          #{s[:joins]}
          WHERE #{RdfModel.sanitize_where(conditions)}
        })
      end
      context.merge!(results.uniq, @as)
      return true
    end
  end
end
