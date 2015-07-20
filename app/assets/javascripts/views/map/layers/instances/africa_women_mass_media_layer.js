define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_women_mass_media_cartocss.cartocss',
  'text!views/map/layers/sql/africa_women_mass_media_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaWomenMassMediaAccessLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: '20%',
          max: '75%',
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

  return AfricaWomenMassMediaAccessLayer;

});
