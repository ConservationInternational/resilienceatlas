define([
  'backbone',
  'uri/URI',
  'views/pages/map_page_view'
], function(Backbone, URI, MapPageView) {

  'use strict';

  var Router = Backbone.Router.extend({

    routes: {
      //'': 'map',
      'map(/:tab)': 'map'
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

    map: function(tab) {

      if (!this.mapPageView) {
        this.mapPageView = new MapPageView({ el: '#pageView' });
      }

      var params = new URI((new URI(location.href).fragment())).search(true);

      if (tab) {
        _.extend(params, { tab: tab});
      }

      this.mapPageView.model.set({ title: 'Map', params: params });
    },

    update: function(params) {
      var uri = new URI(location.href).search(params);
      this.navigate(uri.pathname() + uri.search(), false);
    }

  });

  return Router;

});
