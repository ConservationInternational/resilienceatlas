define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_livelihoodzones_cartocss.cartocss',
  'text!views/map/layers/sql/africa_livelihoodzones_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaLivelihoodZonesLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''/*,
        legend: {
         type: 'custom'
         data: [
           { name: 'category', value: '#color' },
           { name: 'category', value: '#color' },
           { name: 'category', value: '#color' },
           { name: 'category', value: '#color' },
           { name: 'category', value: '#color' },
         ]
       }*/
      }
    }

  });

  return AfricaLivelihoodZonesLayer;

});
