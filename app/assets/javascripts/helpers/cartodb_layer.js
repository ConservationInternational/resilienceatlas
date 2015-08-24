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
      //old adress
      // maps_api_template: 'https://grp.cidata.io/user/{user}',
      // sql_api_template: 'https://grp.cidata.io/user/{user}',
      // New adress
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

          layer.bind('load', function() {
            self.loader.removeClass('is-loading');
          });

        }.bind(this))
        .on('error', function(err) {
          throw err;
        });
    },

    /**
     * Create a CartoDB RASTER layer -- solving the bug
     * @param  {Function} callback
     */
    createRasterLayer: function() {
      // console.log('raster layer');

      var sql = this.options.sublayers[0].sql;
      var cartocss = this.options.sublayers[0].cartocss;

      var config = {
        'layers': [{
          'type': 'cartodb',
          'options': {
            'sql': sql,
            'cartocss': cartocss,
            'cartocss_version': '2.3.0',
            'geom_column': 'the_raster_webmercator',
            'geom_type': 'raster',
            'raster_band': '1'
          }
        }]
      };

      var self = this;
      var map = this.map;
      //Carto URL
      // var url = "http://cigrp.cartodb.com/api/v1/map";
      //Their URL
      var url = "https://grp.global.ssl.fastly.net/user/grp/api/v1/map/";

      $.ajax({
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        url: url,
        data: JSON.stringify(config),
        success: function(response) {
          var layergroup = response;
          var tilesEndpoint = url + '/' + layergroup.layergroupid + '/{z}/{x}/{y}.png';
          var protocol = 'https:' === document.location.protocol ? 'https' : 'http';

          if (layergroup.cdn_url && layergroup.cdn_url[protocol]) {
            var domain = layergroup.cdn_url[protocol];
            if ('http' === protocol) {
              domain = '{s}.' + domain;
            }
            //Carto URL
            // tilesEndpoint = protocol + '://' + domain + '/' + 'cigrp/api/v1/map/' + layergroup.layergroupid + '/{z}/{x}/{y}.png';
            //Their URL
            tilesEndpoint = "https://grp.global.ssl.fastly.net/user/grp/api/v1/map/" + layergroup.layergroupid + '/{z}/{x}/{y}.png';
          }

          self.layer = L.tileLayer(tilesEndpoint, {
            maxZoom: 18
          }).addTo(map);

        },
        error: function(){
          Backbone.Events.trigger('spin:stop');
        }
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
    }

  });

})(this);
