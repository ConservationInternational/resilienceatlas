define(['lib/class'], function(Class) {

  'use strict';

  var Facade = Class.extend({

    init: function() {
      this._methods = {};
    },

    set: function(name, value) {
      this._methods[name] = value;
    },

    get: function(name) {
      return this._methods[name];
    }

  });

  return new Facade();

});
