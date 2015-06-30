define([
  'underscore',
  'lib/class',
  'text!templates/map/custom_map_info_window.handlebars'
], function(_, Class, infoWindowTPL) {

  'use strict';

  var CartoDBLayer = Class.extend({

    defaults: {
      username: 'cigrp'
    },

    init: function(settings) {
      var options = settings && settings.options ? settings.options : {};
      this.options = _.extend(this.defaults, this.options || {}, options);
    },

    /**
     * Add a layer to map
     * @param  {Object} map
     */
    addLayer: function(map) {
      var self = this;
      var options = _.clone(this.options);
      var zindex = options.zIndex;
      var opacity = options.opacity;
      var interactivity = options.interactivity;
      var locateLayer = options.locateLayer;
      var slug = options.slug;

      this.map = map;

      Backbone.Events.trigger('layer:loading', slug);

      cartodb.createLayer(map, {
        user_name: 'cigrp',
        type: 'cartodb',
        sublayers: [{
          sql: options.params.q,
          cartocss: options.params.cartocss,
          interactivity: interactivity
        }]
      })
      .addTo(map)
      .done(function(layer) {
        layer.setZIndex(zindex);
        layer.setOpacity(opacity);
        self.layer = layer;

        layer.bind('load', function() {
          Backbone.Events.trigger('layer:finishLoading', slug);
        });

        if(locateLayer) {
          var sql = new cartodb.SQL({ user: options.username});
          sql.getBounds(options.params.q).done(function(bounds) {
            self.bounds = bounds;
          });
        }

        if(interactivity) {
          self.addInfoWindow(interactivity);
        }
      });
    },

    /**
     * Removes a layer
     */
    removeLayer: function() {
      if (this.map && this.layer) {
        this.map.removeLayer(this.layer);
      }
    },

    updateLayer: function() {
      this.removeLayer();
      this.addLayer(this.map);
    },

    panToLayer: function() {
      var bounds = this.bounds;

      if(bounds) {
        this.map.fitBounds(bounds, {maxZoom: this.map.getZoom()});
      }
    },

    addInfoWindow: function(interactivity) {
      if(this.infoWindow) {
        this.infoWindow.remove();
      }

      var sublayer = this.layer.getSubLayer(0);
      var columns = _.allKeys(interactivity);
      var names = JSON.stringify(_.values(interactivity));
      var tpl = '<% var colNames = %1 %>'.format(names) + infoWindowTPL;

      this.infoWindow = cdb.vis.Vis.addInfowindow(this.map,
        sublayer,
        columns, {
          infowindowTemplate: tpl,
          templateType: 'underscore',
        });
    }

  });

  return CartoDBLayer;

});
