(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Journeys = Backbone.Collection.extend({

    //TODO == set different url for different journeys
    url: '/journeys/1.json',
    // url: function(data) {
    //   console.log(data);
    //   return '/journeys/' + data + '.json';
    // },

    parse: function(response) {
      // console.log(this.url);

      var result = response;
      return result;
    }


  });


})(this);
