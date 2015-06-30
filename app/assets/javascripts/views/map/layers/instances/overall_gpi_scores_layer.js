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
        type: ''
      }
    }

  });

  return OverallGpiScoresLayer;

});
