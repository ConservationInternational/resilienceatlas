define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/overall_gpi_scores_cartocss.cartocss',
  'text!views/map/layers/sql/overall_gpi_scores_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var OverallGpiScoresLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: '1.90',
          max: '3.49',
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

  return OverallGpiScoresLayer;

});
