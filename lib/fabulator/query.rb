module Fabulator
  module RdfActions
  class Query
    attr_accessor :as

    def initialize(xml, def_model = nil)
      @model = (xml.attributes.get_attribute_ns(FAB_NS, 'rdf-model').value rescue def_model)
      @model = def_model if @model.nil? || @model.blank?
      @select= (xml.attributes.get_attribute_ns(FAB_NS, 'select').value rescue '')
#      @goto  = (xml.attributes.get_attribute_ns(FAB_NS, 'go-to').value rescue nil)
      parser = Fabulator::XSM::ExpressionParser.new
      @select = (parser.parse(@select, xml) rescue nil)
      @as = nil

      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end

      Rails.logger.info("Query object initialized")
    end

    def run(c)
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', @model ])
      return [] if rdf_model.nil?

      context = (@select.run(c).first rescue c)

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
                  possible = p[1].run(context).collect{|c| c.value} - [ nil ]
                  Rails.logger.info("Ran #{YAML::dump(p[1])}\n and got #{YAML::dump(possible)}")
                  conditions << RdfLiteral.find(:all, :conditions => [ 'obj_lit in ?', possible ]).collect{|c| c.id}
                end
              when :resource:
                if p[1].is_a?(String)
                  conditions << (RdfResource.from_uri(p[1], rdf_model.rdf_namespace).id rescue 0)
                else
                  possible = p[1].run(context).collect{|c| c.value} - [ nil ]
                  Rails.logger.info("Ran #{YAML::dump(p[1])}\n and got #{YAML::dump(possible)}")
                  conditions << possible.collect{|u| Rails.logger.info("Looking up resource for #{u}"); RdfResource.from_uri(u, rdf_model.rdf_namespace).id rescue 0}
                end
              when :namespace:
                conditions << (RdfNamespace.first(:conditions => [ 'namespace = ?', p[1] ]).id rescue 0)
            end
          end
        end
        conditions = conditions - [0, nil, []]
        if (" " + s[:simple_where] + " ").split('%s').length == conditions.length
          results = results + RdfQueryResult.find_by_sql(
          %{
            SELECT DISTINCT #{s[:select]}
            FROM #{s[:from]}
            #{s[:joins]}
            WHERE #{RdfModel.sanitize_where(conditions)}
          }, rdf_model.namespace, s[:sql_to_ctx])
        end
      end
      if !results.empty?
        Rails.logger.info("Merging #{YAML::dump(results)}")
        res_ctx = [ ]
        results.each do |r|
          c = Fabulator::XSM::Context.new(
            'data', context.roots, nil, [], nil
          )
          c.merge_data(r)
          res_ctx << c
        end
        # here, we do sub-queries for bags, sets, lists, etc.
        Rails.logger.info("Returning #{YAML::dump(res_ctx)}")
        return res_ctx
      end
      return [ ]
    end
  end
  end
end
