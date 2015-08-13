(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Journeys = Backbone.Collection.extend({

    url: '/journeys/',

    parse: function(response) {
      //just in case we need to parse some data later...
      var result = response;
      return result;
    },

    getByParams: function(journey) {
      this.url = this.url + journey + '.json';
      return this.fetch();
    }

  });


})(this);
