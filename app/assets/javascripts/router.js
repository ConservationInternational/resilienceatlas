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

      tab = tab ? tab : 'layers';

      _.extend(params, { tab: tab});

      this.mapPageView.model.set({ title: 'Map', params: params });
    },

    update: function(params) {
      var uri = new URI(location.href),
        urlParams = '';

      // add param
      if (params.layerValue) {
        var hasParams = uri.hash().split('=');

        // Check if exists previous active layers
        if (hasParams && hasParams[1]) {
          // Check if slug exists yet

          var activeParams = hasParams[1].split(','),
            isExists = false;


          activeParams.forEach(function(active) {
            if (active === params.slug) {
              isExists = true;
              return;
            }
          });

          if (!isExists) {
            urlParams = ',' + params.slug;
          }

        } else {
          urlParams = '?active=' + params.slug;
        }

        this.navigate(uri.hash() + urlParams, false);

      // remove param
      } else {

        var activeParams = new URI (uri.fragment()).query();

        if (activeParams.split('=').length > 0 && activeParams.split('=')[1]) {
          var p = activeParams.split('=')[1];

          var totalParams = p.split(',').length;

          p.split(',').forEach(function(a, index, o) {
            if (a === params.slug) {
              if (index === 0 && totalParams === 1) {
                urlParams = activeParams.split('=')[1].replace(params.slug, '');

              } else if(index === 0 && totalParams > 1) {
                urlParams = activeParams.split('=')[1].replace(params.slug + ',', '');
                urlParams = '?active=' + urlParams;
              } else {
                urlParams = activeParams.split('=')[1].replace(',' + params.slug, '');
                urlParams = '?active=' + urlParams;
              }
            }
          });
        }

        this.navigate(uri.hash().split('?')[0] + urlParams, false);
      }
    }

  });

  return Router;

});
