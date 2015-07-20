define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/horn_africa_chirps_long_rains_total_cartocss.cartocss',
  'text!views/map/layers/sql/horn_africa_chirps_long_rains_total_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var HornAfricaChirpsLongRainsTotalLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        raster: true,
        legend: {
          min: '-30%',
          max: '30%',
          type: 'choropleth',
          bucket: [
            '#007FFE',
            '#419FFE',
            '#7DBEFE',
            '#FEF1CB',
            '#FEA5A5',
            '#FF7A7A',
            '#FF4D4D'
          ]
        }
      }
    }

  });

  return HornAfricaChirpsLongRainsTotalLayer;

});
