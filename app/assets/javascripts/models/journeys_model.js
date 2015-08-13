(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Model = root.app.Model || {};

  root.app.Model.Journeys = Backbone.Model.extend({

    defaults: {
      journey: 1,
      step: 0
    }

  });


})(this);
