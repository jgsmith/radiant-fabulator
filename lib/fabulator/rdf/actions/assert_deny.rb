module Fabulator
  module Rdf
  module Actions
  class AssertDeny
    attr_accessor :state

    def compile_xml(xml, c_attrs = { })
      @model_x = ActionLib.get_attribute(RDFA_NS, 'model', c_attrs)
      @state = xml.attributes.get_attribute_ns(RDFA_NS, 'go-to').value rescue nil
      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end
      #fc = xml.elements.first
      #if fc.namespace == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' &&
      #   fc.local_name == 'RDF'
      #  @sql = RdfModel.build_query(fc.to_s)
      #end
      #@sql[:type_ns] = fc.namespace
      #@sql[:type_ln] = fc.local_name
      self
    end

    def count(s, context)
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model_x.run(context).first.value ])
      return 0 if rdf_model.nil?

      conditions = [ s[:simple_where] ]
      s[:where_params].each do |p|
        if p == :model
          conditions << rdf_model.id
        elsif p.is_a?(Array)
          case p[0]
            when :literal:
              conditions << ((RdfLiteral.first(:conditions => [ 'obj_lit = ?', p[1] ]).id rescue 0) || 0)
            when :resource:
              conditions << ((RdfResource.from_uri(p[1], rdf_model.rdf_namespace).id rescue 0) || 0)
            when :namespace:
              conditions << ((RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0) || 0)
          end
        end
      end
      RdfQueryResult.count_by_sql(%{
        SELECT COUNT(#{s[:select].gsub(/AS.+$/,'')})
        FROM #{s[:from]}
        #{s[:joins]}
        WHERE #{RdfModel.sanitize_where(conditions)}
        LIMIT 1
      }, rdf_model.namespace, s[:sql_to_ctx])
    end
  end

  class Assert < AssertDeny
    def run(context)
      @sql.each do |s|
        return [ ] if self.count(s,context) > 0
      end
      raise Fabulator::StateChangeException, self.state, caller
      #context.state = self.state
      #return false
    end
  end

  class Deny < AssertDeny
    def run(context)
      @sql.each do |s|
        return [] if self.count(s,context) == 0
      end
      raise Fabulator::StateChangeException, self.state, caller
      #context.state = self.state
      #return false
    end
  end
  end
  end
end
