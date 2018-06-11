(function(root) {

  'use strict';

  Handlebars.registerHelper("ifcond", function (val) {
    var result = val !== 100 ? 'is-modified' : null;
    return result
  });

  Handlebars.registerHelper('compare', function(lvalue, operator, rvalue, options) {
    if(arguments.length < 4) {
      throw new Error('Handlerbars Helper "compare" needs 3 parameters');
    }

    var operators = {
      '==':     function (l, r) { return l        ==  r; },
      '===':    function (l, r) { return l        === r; },
      '!=':     function (l, r) { return l        !=  r; },
      '!==':    function (l, r) { return l        !== r; },
      '<':      function (l, r) { return l        <   r; },
      '>':      function (l, r) { return l        >   r; },
      '<=':     function (l, r) { return l        <=  r; },
      '>=':     function (l, r) { return l        >=  r; },
      'typeof': function (l, r) { return typeof l ==  r; }
    };

    if (!operators[operator]) {
      throw new Error('Handlerbars Helper "compare" doesn\'t know the operator ' +
        operator);
    }

    var res = operators[operator](lvalue, rvalue);

    if (res) {
        return options.fn(this);
    }

    return options.inverse(this);
  });

})(this);
