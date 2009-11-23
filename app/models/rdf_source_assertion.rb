class RdfSourceAssertion < ActiveRecord::Base
  belongs_to :rdf_resource
  belongs_to :rdf_statement
end
