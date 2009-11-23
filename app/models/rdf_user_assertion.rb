class RdfUserAssertion < ActiveRecord::Base
  belongs_to :user
  belongs_to :rdf_statement
end
