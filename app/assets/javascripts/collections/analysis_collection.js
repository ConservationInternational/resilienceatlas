(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Analysis = Backbone.Collection.extend({

    url: 'data/analysis.json',

    initialize: function() {
      
    }

  });

})(this);