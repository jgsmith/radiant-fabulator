require 'fabulator/rdf/actions/assert_deny'
require 'fabulator/rdf/actions/assertion'
require 'fabulator/rdf/actions/denial'
require 'fabulator/rdf/actions/query'

module Fabulator
#  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
#  RDFA_NS = 'http://dh.tamu.edu/ns/fabulator/rdf/1.0#'

  module Rdf
  module Actions
  class Lib
 
    include ActionLib
    register_namespace RDFA_NS

    register_attribute 'model'

    action 'assert'    , Assert
    action 'deny'      , Deny
    action 'assertion' , Assertion
    action 'denial'    , Denial
    action 'query'     , Query
  end
  end
  end
end
