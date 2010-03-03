module Fabulator
  module Rdf
  module Actions
  class Query
    attr_accessor :as

    def compile_xml(xml, c_attrs = { })
      @model_x = ActionLib.get_attribute(RDFA_NS, 'model', c_attrs)
      @select = ActionLib.get_local_attr(xml, FAB_NS, 'select', { :eval => true, :default => '.'})

      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e)
      end
      self
    end

    def run(c, autovivify = false)
      Rails.logger.info("Query running!\n\n\n")
      model = (@model_x.run(c).first.value rescue nil)
      Rails.logger.info("model: #{model}")
      return [] if model.nil?
      rdf_model = RdfModel.first(:conditions => [ 'name = ?', model ])
      Rails.logger.info("rdf model: #{rdf_model}")
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
                  #Rails.logger.info("Ran #{YAML::dump(p[1])}\n and got #{YAML::dump(possible)}")
                  conditions << RdfLiteral.find(:all, :conditions => [ 'obj_lit in ?', possible ]).collect{|c| c.id}
                end
              when :resource:
                if p[1].is_a?(String)
                  conditions << (RdfResource.from_uri(p[1], rdf_model.rdf_namespace).id rescue 0)
                else
                  possible = p[1].run(context).collect{|c| c.value} - [ nil ]
                  #Rails.logger.info("Ran #{YAML::dump(p[1])}\n and got #{YAML::dump(possible)}")
                  conditions << possible.collect{|u| 
                    # Rails.logger.info("Looking up resource for #{u}") 
                    (RdfResource.from_uri(u, rdf_model.rdf_namespace).id rescue 0)
                  }
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
          c = Fabulator::Expr::Node.new(
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
end
