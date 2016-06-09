(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Analysis = Backbone.Collection.extend({

    url: function() {
      var url = 'data/analysis.json';
      var isSubdomain = window.isSubdomain;

      if (isSubdomain === 'indicators' || isSubdomain === 'atlas') {
        url = 'data/analysis_vital_signs.json';
      }

      return url;
    },

    initialize: function() {

    }

  });

})(this);
