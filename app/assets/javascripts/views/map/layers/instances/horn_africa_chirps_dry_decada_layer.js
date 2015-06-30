define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/horn_africa_chirps_dry_decada_cartocss.cartocss',
  'text!views/map/layers/sql/horn_africa_chirps_dry_decada_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var HornAfricaChirpsDryDecadaLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        raster: true
      }
    }

  });

  return HornAfricaChirpsDryDecadaLayer;

});