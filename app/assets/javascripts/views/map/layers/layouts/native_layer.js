define([
  'underscore',
  'uri/URI',
  'lib/class'
], function(_, URI, Class) {

  'use strict';

  var NativeLayer = Class.extend({

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
      this.map = map;
      this.getData().done(function(data) {
        var geojson = self.toGeoJSON(data.rows);
        self.layer = L.geoJson(geojson, {
          style: function() {
            return {
              fillColor: "#ff7800",
              color: "#ff0000",
              weight: 0.5,
              opacity: 1,
              fillOpacity: 0.7
            };
          }
        });
        map.addLayer(self.layer);
      });
    },

    /**
     * Method to remove layer
     */
    removeLayer: function() {
      if (this.map && this.layer) {
        this.map.removeLayer(this.layer);
      }
    },

    /**
     * Method to fetch data
     * @return {Ajax}
     */
    getData: function() {
      var url = 'http://%1.cartodb.com/api/v2/sql/'
        .format(this.options.username);
      var params = this.options.params;
      var uri = new URI(url).search(params);
      return $.get(uri.href());
    },

    /**
     * Helper to parse JSON to GeoJSON
     * @param  {Object} data
     * @return {Object}
     */
    toGeoJSON: function(data) {
      var geojson = {
        type: 'FeatureCollection',
        features: _.map(data, function(d) {
          return {
            type: 'Feature',
            geometry: JSON.parse(d.geom),
            properties: { id: d.id }
          };
        })
      };
      return geojson;
    }

  });

  return NativeLayer;

});
