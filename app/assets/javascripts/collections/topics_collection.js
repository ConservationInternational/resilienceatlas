define([
  'backbone'
], function(Backbone, data) {

  'use strict';

  var TopicsCollection = Backbone.Collection.extend({

    url: 'http://cigrp.cartodb.com/api/v2/sql',

    parse: function(data) {
      return data;
    },

    getTopic: function(id) {
      var topicId = Number(id);
      return _.findWhere(this.toJSON(), {id: topicId});
    },

    getTopicsList: function() {
      return _.groupBy(this.toJSON(), 'category');
    }

  });

  return TopicsCollection;

});
