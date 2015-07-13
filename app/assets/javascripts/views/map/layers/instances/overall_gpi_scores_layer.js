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
          min: 'More peaceful',
          max: 'Less peaceful',
          type: 'choropleth',
          bucket: [
            '#007FFE',
            '#419FFE',
            '#FEF1CB',
            '#FF7A7A',
            '#FF4D4D'
          ]
        }
      }
    }

  });

  return OverallGpiScoresLayer;

});
