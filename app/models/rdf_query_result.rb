class RdfQueryResult < ActiveRecord::Base
  # we don't want these instatitated into classes.  We just want an array
  # of hashes returned.
  def self.find_by_sql(sql, base = nil, sql2ctx = { })
    base = base.to_s unless base.nil?
    connection.select_all(sanitize_sql(sql), "#{name} Load").collect!{ |record|
      fields = record.keys.select {|k| k =~ /_id$/}.collect{|k| k.gsub(/_id$/,'') }
      r = { }
      sql2ctx = { } if sql2ctx.nil?
      fields.each do |f|
        sql2ctx[f] = f unless sql2ctx[f]
        if record[f+'_type']
          t = self.compute_type(record[f+'_type'])
          r[sql2ctx[f]] = t.find(record[f+'_id'])
        else
          v = RdfResource.find(record[f+'_id'])
          if !base.nil?
            if v.rdf_namespace.namespace == base
              v = v.local_name
            end
          end
          r[sql2ctx[f]] = v
        end
        r[sql2ctx[f]] = r[sql2ctx[f]].to_s
      end
      r
    }
  end
end
