(function(root) {

  'use strict';

  Handlebars.registerHelper("ifcond", function (val) {
    var result = val !== 100 ? 'is-modified' : null;
    return result
  });

})(this);
