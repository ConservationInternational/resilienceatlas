define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/horn_africa_chirps_dry_total_cartocss.cartocss',
  'text!views/map/layers/sql/horn_africa_chirps_dry_total_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var HornAfricaChirpsDryTotalLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        raster: true
      }
    }

  });

  return HornAfricaChirpsDryTotalLayer;

});