define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_organized_conflict_internal_cartocss.cartocss',
  'text!views/map/layers/sql/africa_organized_conflict_internal_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaOrganizedConflictInternalLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: 'Low',
          max: 'High',
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

  return AfricaOrganizedConflictInternalLayer;

});