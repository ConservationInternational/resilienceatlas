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
        type: '',
        legend: {
         type: 'custom'
         data: [
           { name: 'Agro-Forestry', value: '#135e11' },
           { name: 'Agro-Pastoral', value: '#229A00' },
           { name: 'Arid', value: '#c9c09e' },
           { name: 'Crops - Floodzone', value: '#00edff' },
           { name: 'Crops - Irrigated', value: '#0091ff' },
           { name: 'Crops - Rainfed', value: '#FF9900' },
           { name: 'Fishery', value: '#1556b2' },
           { name: 'National Park', value: '#b0e5a0' },
           { name: 'Pastoral', value: '#e8ffd3' },
           { name: 'Urban', value: '#6d6d6d' },
           { name: 'Others', value: '#7a693c' }
         ]
       }
      }
    }

  });

  return AfricaLivelihoodZonesLayer;

});