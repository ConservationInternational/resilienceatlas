define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_political_inestability_cartocss.cartocss',
  'text!views/map/layers/sql/africa_political_inestability_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaPoliticalInestabilityLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: 'Stable',
          max: 'Unstable',
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

  return AfricaPoliticalInestabilityLayer;

});