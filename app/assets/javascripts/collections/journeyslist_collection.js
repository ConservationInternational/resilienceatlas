(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.JourneysList = Backbone.Collection.extend({

    url: '/journeys/list.json',

    parse: function(response) {
      return response;
    },


  });

})(this);
