define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_children_stunted_cartocss.cartocss',
  'text!views/map/layers/sql/africa_children_stunted_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaChildrenStuntedLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: '0%',
          max: '60%',
          type: 'choropleth',
          bucket: [
            '#1a9850',
            '#8cce8a',
            '#d2ecb4',
            '#fff2cc',
            '#fed6b0',
            '#f79272',
            '#d73027'
          ]
        }
      }
    }

  });

  return AfricaChildrenStuntedLayer;

});