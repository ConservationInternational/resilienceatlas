define([
  'backbone'
], function(Backbone) {

  var TopicsCollection = Backbone.Collection.extend({

    parse: function(data) {
      return data;
    }

  });

  return TopicsCollection;

});
