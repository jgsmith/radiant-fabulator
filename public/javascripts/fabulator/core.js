/*
 * Some core Fabulator JS support
 */

var Fabulator = Fabulator || { };

(function($, Fabulator) {

  var genericNamespacer = function(base, nom) {
    if(typeof(base[nom]) == "undefined") {
      base[nom] = { };
      base[nom].namespace = function(nom2) {
        return genericNamespacer(base[nom], nom2);
      };
    }
    return base[nom];
  };

  Fabulator.namespace = function(nom) {
    return genericNamespacer(Fabulator, nom);
  };

})(jQuery, Fabulator);
