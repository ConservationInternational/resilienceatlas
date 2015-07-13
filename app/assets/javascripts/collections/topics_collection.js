define([
  'backbone'
], function(Backbone, data) {

  'use strict';

  var TopicsCollection = Backbone.Collection.extend({

    url: 'http://cigrp.cartodb.com/api/v2/sql',

    parse: function(data) {
      return data;
    },

    getTopics: function() {
      return _.groupBy(this.toJSON(), 'category');
    }

  });

  return TopicsCollection;

});
