/*
 * Some core Fabulator JS support
 */

var Fabulator = Fabulator || { };

(function($, Fabulator) {

  if(window.console != undefined && window.console.log != undefined) {
    Fabulator.debug = function() {
      console.log(Array.prototype.slice.call(arguments));
    };
  }
  else {
    Fabulator.debug = function() { };
  }

  var genericNamespacer = function(base, nom) {
    if(typeof(base[nom]) == "undefined") {
      base[nom] = { };
      base[nom].namespace = function(nom2) {
        return genericNamespacer(base[nom], nom2);
      };
      base[nom].debug = Fabulator.debug;
    }
    return base[nom];
  };

  Fabulator.namespace = function(nom) {
    return genericNamespacer(Fabulator, nom);
  };

})(jQuery, Fabulator);
