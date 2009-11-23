class RdfType < ActiveRecord::Base
  has_many :rdf_literals

    #  t.references :rdf_type
    #  t.references :rdf_language
    #  t.text       :object_lit

end
