define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/horn_africa_chirps_long_rains_coefvariation_change_cartocss.cartocss',
  'text!views/map/layers/sql/horn_africa_chirps_long_rains_coefvariation_change_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var HornAfricaChirpsLongRainsCoefvariationChangeLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        raster: true
      }
    }

  });

  return HornAfricaChirpsLongRainsCoefvariationChangeLayer;

});