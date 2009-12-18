module Fabulator
  #FAB_NS='http://dh.tamu.edu/ns/fabulator/1.0#'
  class Query
    attr_accessor :as

    def initialize(xml, def_model = nil)
      @model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model)
      @as    = (xml.attributes.get_attribute_ns(FAB_NS, 'as').value.split(/\//) rescue []) - [ '', nil ]
      @goto  = (xml.attributes.get_attribute_ns(FAB_NS, 'go-to').value rescue nil)
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
        conditions = [ s[:simple_where] ]
        s[:where_params].each do |p|
          if p == :model
            conditions << rdf_model.id
          elsif p.is_a?(Array)
            case p[0]
              when :literal:
                if p[1].is_a?(String)
                  conditions << (RdfLiteral.first(:conditions => [ 'obj_lit = ?', p[1] ]).id rescue 0)
                else
                  possible = p[1].run(context.data).collect{|c| c.value} - [ nil ]
                  conditions << RdfLiteral.find(:all, :conditions => [ 'obj_lit in ?', possible ]).collect{|c| c.id}
                end
              when :resource:
                if p[1].is_a?(String)
                  conditions << (RdfResource.from_uri(p[1]).id rescue 0)
                else
                  possible = p[1].run(context.data).collect{|c| c.value} - [ nil ]
                  conditions << possible.collect{|u| RdfResource.from_uri(u).id rescue nil} - [ nil ]
                end
              when :namespace:
                conditions << (RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0)
            end
          end
        end
        if (" " + s[:simple_where] + " ").split('%s').length == conditions.length
          results = results + RdfQueryResult.find_by_sql(%{
            SELECT DISTINCT #{s[:select]}
            FROM #{s[:from]}
            #{s[:joins]}
            WHERE #{RdfModel.sanitize_where(conditions)}
          })
        end
      end
      if !results.empty? && !@goto.nil?
        context.merge!(results.uniq, @as)
        context.state = @goto
        return false
      end
      return true
    end
  end
end
