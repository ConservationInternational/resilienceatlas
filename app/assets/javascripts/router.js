define([
  'backbone',
  'uri/URI',
  'views/pages/map_page_view'
], function(Backbone, URI, MapPageView) {

  'use strict';

  var Router = Backbone.Router.extend({

    routes: {
      '': 'index'
    },

    initialize: function() {
      this.setListeners();
    },

    setListeners: function() {
      Backbone.Events.on('dashboard:change', this.update, this);
    },

    index: function() {
      var params = new URI(location.href).search(true);
      var mapPageView = new MapPageView({ el: '#pageView' });
      mapPageView.model.set({ title: 'Map', params: params });
    },

    update: function(params) {
      var uri = new URI(location.href).search(params);
      this.navigate(uri.pathname() + uri.search(), false);
    }

  });

  return Router;

});
