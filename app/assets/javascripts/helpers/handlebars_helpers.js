(function(root) {

  'use strict';

  Handlebars.registerHelper("ifcond", function (val) {
    var result = val !== 100 ? 'is-modified' : null;
    return result
  });

  Handlebars.registerHelper('if_eq', function(a, b, opts) {
    if(a === b) {
      return opts.fn(this);
    } else {
      return opts.inverse(this);
    }
  });

})(this);
