(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  /**
   * A wrapper for CartoDB
   * More info: http://docs.cartodb.com/cartodb-platform/cartodb-js.html
   */
  root.app.Helper.XYZTiles = root.app.Helper.Class.extend({

    initialize: function(map, settings) {
      if (!map && map instanceof L.Map) {
        throw 'First params "map" is required and a valid instance of L.Map.';
      }
      var opts = settings || {};
      this.options = _.extend({}, this.defaults, opts);
      this._setMap(map);

      this.cacheVars();
    },

    cacheVars: function() {
      this.loader = $('.m-loader');
    },

    /**
     * Create a CartoDB RASTER layer
     * @param  {Function} callback
     */
    create: function(callback) {
      this.loader.addClass('is-loading');

      var tilesEndpoint = this.options.sql;

      var self = this;
      var map = this.map;

      self.layer = L.tileLayer(tilesEndpoint, {
        maxZoom: 18
      }).addTo(map);

      // Standardize the layer object
      // Carto layers have a show and hide
      // functions
      self.layer.show = function() {
        self.layer.addTo(map);
      };

      self.layer.hide = function() {
        map.removeLayer(self.layer);
      };

      self.loader.removeClass('is-loading');

      if (callback && typeof callback === 'function') {
        callback.apply(self, [self.layer]);
      }
    },

    /**
     * Remove cartodb layer and sublayers
     */
    remove: function() {
      if (this.layer) {
        this.map.removeLayer(this.layer);
      } else {
        console.info('There isn\'t a layer.');
      }
    },

    /**
     * Set Leaflet map
     * @param {[type]} map [description]
     */
    _setMap: function(map) {
      this.map = map;
    }

  });

})(this);
