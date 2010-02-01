require 'fabulator/rdf_actions/assert_deny'
require 'fabulator/rdf_actions/assertion'
require 'fabulator/rdf_actions/denial'
require 'fabulator/rdf_actions/query'

module Fabulator
  class RdfActions
    include ActionLib
    register_namespace RDFA_NS

    action 'rdf-assert'    , RdfActions::Assert
    action 'rdf-deny'      , RdfActions::Deny
    action 'rdf-assertion' , RdfActions::Assertion
    action 'rdf-denial'    , RdfActions::Denial
    action 'rdf-query'     , RdfActions::Query
  end
end
