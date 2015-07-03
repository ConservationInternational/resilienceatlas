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
          min: '10.6',
          max: '135',
          type: 'choropleth',
          bucket: [
            '#d73027',
            '#f79272',
            '#fed6b0',
            '#fff2cc',
            '#d2ecb4',
            '#8cce8a',
            '#1a9850'
          ]
        }
      }
    }

  });

  return AfricaWomenMassMediaAccessLayer;

});