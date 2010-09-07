require 'fabulator/rdf/actions/assert_deny'
require 'fabulator/rdf/actions/assertion'
require 'fabulator/rdf/actions/denial'
require 'fabulator/rdf/actions/query'

module Fabulator
#  RDF_NS = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
#  RDFA_NS = 'http://dh.tamu.edu/ns/fabulator/rdf/1.0#'

  module Rdf
  module Actions
  class Lib < TagLib
 
    namespace RDFA_NS

    register_attribute 'model'

    action 'assert'    , Fabulator::Rdf::Actions::Assert
    action 'deny'      , Fabulator::Rdf::Actions::Deny
    action 'assertion' , Fabulator::Rdf::Actions::Assertion
    action 'denial'    , Fabulator::Rdf::Actions::Denial
    action 'query'     , Fabulator::Rdf::Actions::Query

  end
  end
  end
end
