(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  /**
   * A wrapper for CartoDB
   * More info: http://docs.cartodb.com/cartodb-platform/cartodb-js.html
   */
  root.app.Helper.CartoDBLayer = root.app.Helper.Class.extend({

    defaults: {
      user_name: 'grp', // Required
      type: 'cartodb', // Required
      cartodb_logo: false,
      maps_api_template: 'https://grp.global.ssl.fastly.net/user/{user}',
      sql_api_template: 'https://grp.global.ssl.fastly.net/user/{user}',
      sublayers: [{
        sql: 'SELECT * FROM table_name', // Required
        cartocss: '#table_name {marker-fill: #F0F0F0;}', // Required
        interactivity: 'column1, column2, ...' // Optional
      }]
    },

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
     * Create a CartoDB layer
     * @param  {Function} callback
     */
    create: function(callback) {
      this.loader.addClass('is-loading');
      cartodb.createLayer(this.map, this.options, { 'no_cdn': true })
        .addTo(this.map)
        .on('done', function(layer) {
          this.layer = layer;
          if (callback && typeof callback === 'function') {
            callback.apply(this, arguments);
          }

          var self = this;

          self._getLayerBounds(layer);

          layer.bind('load', function() {
            self.loader.removeClass('is-loading');
          });

        }.bind(this))
        .on('error', function(err) {
          throw err;
        });
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
    },

    _getLayerBounds: function(layer) {
      var self = this;
      var sublayer = this.options.sublayers && this.options.sublayers[0];
      var sql = sublayer.sql;
      var sqlBounds = new cartodb.SQL({ 
        user: this.options.user_name,
        sql_api_template: this.options.sql_api_template
      });

      if(sublayer.raster) {
        sql = 'SELECT ST_Union(ST_Envelope(the_raster_webmercator)) as the_geom FROM (' + sql + ') as t';
      }

      sqlBounds.getBounds(sql).done(function(bounds) {
        self.bounds = bounds;
      }); 
    },

    panToLayer: function() {
      var bounds = this.bounds;

      if(bounds) {
        this.map.fitBounds(bounds);
      }
    }

  });

})(this);
