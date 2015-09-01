(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  /**
   * A wrapper for CartoDB
   * More info: http://docs.cartodb.com/cartodb-platform/cartodb-js.html
   */
  root.app.Helper.CartoDBmask = root.app.Helper.Class.extend({

    defaults: {
      user_name: 'grp', // Required
      type: 'cartodb', // Required
      // cartodb_logo: false,
      maps_api_template: 'https://grp.cidata.io/user/grp',
      sql_api_template: 'https://grp.cidata.io/user/grp',
      sublayers: [{
        cartocss: "#country_mask{polygon-fill: #FFF;polygon-opacity: 1;line-color: #DDD;}#country_mask[iso_a3='ETH']{polygon-opacity: 0;}",
        sql: "select * from country_mask"
      }]
    },

    initialize: function(map, settings) {
      if (!map && map instanceof L.Map) {
        throw 'First params "map" is required and a valid instance of L.Map.';
      }
      var opts = settings || {};
      this.options = _.extend({}, this.defaults, opts);
      this._setMap(map);
    },

    /**
     * Create a CartoDB layer
     * @param  {Function} callback
     */
    create: function(callback) {

      cartodb.createLayer(this.map, this.options, { 'no_cdn': true })
        .addTo(this.map, 1)
        .on('done', function(layer) {
          this.layer = layer;
          this.layer.getSubLayer(0).set(this.options.sublayers[0]);
          if (callback && typeof callback === 'function') {
            callback.apply(this, arguments);
          }

          var self = this;

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
    }

  });

})(this);