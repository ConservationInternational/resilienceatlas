(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  /**
   * A wrapper for CartoDB
   * More info: http://docs.cartodb.com/cartodb-platform/cartodb-js.html
   */
  root.app.Helper.CartoDBRaster = root.app.Helper.Class.extend({

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
     * Create a CartoDB RASTER layer -- solving the bug
     * @param  {Function} callback
     */
    createRasterLayer: function() {
      this.loader.addClass('is-loading');

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
            tilesEndpoint = "https://grp.global.ssl.fastly.net/user/grp/api/v1/map/" + layergroup.layergroupid + '/{z}/{x}/{y}.png';
          }

          self.layer = L.tileLayer(tilesEndpoint, {
            maxZoom: 18
          }).addTo(map);

          self.loader.removeClass('is-loading');
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
