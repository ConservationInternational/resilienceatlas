(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.JourneysIndex = Backbone.Collection.extend({

    url: '/journeys/journeysPageIndex.json',

    parse: function(response) {
      return response;
    },


  });

})(this);
