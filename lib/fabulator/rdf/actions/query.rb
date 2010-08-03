module Fabulator
  module Rdf
  module Actions
  class Query
    attr_accessor :as

    def compile_xml(xml, context)
      @context = context.merge(xml)
      @model_x = @context.attribute(RDFA_NS, 'model', { :static => false, :inherited => true })
      @select = @context.get_select('.')

      @sql = [ ]
      xml.each_element do |e|
        @sql << RdfModel.build_query(e, @context)
      end
      self
    end

    def run(c, autovivify = false)
      @context.with(c) do |ctx|
        model = (@model_x.run(ctx).first.value rescue nil)
        return [] if model.nil?
        rdf_model = RdfModel.first(:conditions => [ 'name = ?', model ])
        return [] if rdf_model.nil?

        context = (@select.run(ctx).first rescue ctx.root)

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
                    possible = p[1].run(ctx.with_root(context)).collect{|c| c.value} - [ nil ]
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
          res_ctx = [ ]
          results.each do |r|
            c = Fabulator::Expr::Node.new(
              'data', ctx.root.roots, nil, [], nil
            )
            ctx.with_root(c).merge_data(r)
            res_ctx << c
          end
          # here, we do sub-queries for bags, sets, lists, etc.
          return res_ctx
        end
        return [ ]
      end
    end
  end
    end
  end
end
