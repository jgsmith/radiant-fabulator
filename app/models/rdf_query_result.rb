class RdfQueryResult < ActiveRecord::Base
  # we don't want these instatitated into classes.  We just want an array
  # of hashes returned.
  def find_by_sql(sql)
    connection.select_all(sanitize_sql(sql), "#{name} Load")
  end
end
