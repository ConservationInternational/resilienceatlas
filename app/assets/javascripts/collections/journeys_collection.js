(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Journeys = Backbone.Collection.extend({

    // url: '/api/journeys/[id]',
    url: '/data/journeys.json',

    parse: function(response) {
      console.log(response);
      var result = response;
      return result;
    },

    //get step fn() y se la decimos al modelo


  });


})(this);
