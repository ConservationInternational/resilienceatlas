require([
  'backbone',
  'lib/utils',
  'router'
], function(Backbone, utils, Router) {

  'use strict';

  var Application = Backbone.View.extend({

    el: document.body,

    initialize: function() {
      this.router = new Router();
    },

    /**
     * Start history HTML5 API, it's required to use router
     */
    start: function() {
      Backbone.history.start({ pushState: false });
    }

  });

  return new Application().start();

});
