define([
  'backbone',
  'text!queries/regions_query.pgsql'
], function(Backbone, QUERY) {

  'use strict';

  var RegionsCollection = Backbone.Collection.extend({

    url: 'http://cigrp.cartodb.com/api/v2/sql',

    parse: function(data) {
      return _.groupBy(data.rows, 'region');
    },

    getByRegions: function(callback) {
      var options = {
        data: {
          q: QUERY,
          format: 'json'
        },
        success: callback
      };

      this.fetch(options);
    },

  });

  return RegionsCollection;

});
