class RdfQueryResult < ActiveRecord::Base
  # we don't want these instatitated into classes.  We just want an array
  # of hashes returned.
  def self.find_by_sql(sql)
    connection.select_all(sanitize_sql(sql), "#{name} Load").collect!{ |record|
      fields = record.keys.select {|k| k =~ /_id$/}.collect{|k| k.gsub(/_id$/,'') }
      r = { }
      fields.each do |f|
        if record[f+'_type']
          t = self.compute_type(record[f+'_type'])
          r[f] = t.find(record[f+'_id'])
        else
          r[f] = RdfResource.find(record[f+'_id'])
        end
        r[f] = r[f].to_s
      end
      r
    }
  end
end
