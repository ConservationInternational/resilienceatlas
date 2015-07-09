define([
  'backbone',
  'text!queries/topics_query.pgsql'
], function(Backbone, QUERY) {

  var TopicsCollection = Backbone.Collection.extend({

    url: 'http://cigrp.cartodb.com/api/v2/sql',

    parse: function(data) {
      return data.rows;
    },

    getTopics: function() {

      var options = {
        data: {
          q: QUERY,
          format: 'json'
        }
      };

      this.fetch(options);
    }

  });

  return TopicsCollection;

});
