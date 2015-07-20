define([
  'underscore',
  'backbone',
], function(_, Backbone) {

  'use strict';

  var SearchCollection = Backbone.Collection.extend({

    parse: function(data) {
      return data;
    },

    getByCategory: function(category) {
      var data = this.toJSON();
      return _.sortBy(_.where(data, {type: category}),'name');
    }

  });

  return SearchCollection;

});
