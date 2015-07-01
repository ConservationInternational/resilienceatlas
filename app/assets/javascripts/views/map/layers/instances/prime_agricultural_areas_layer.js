define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/prime_agricultural_areas_cartocss.cartocss',
  'text!views/map/layers/sql/prime_agricultural_areas_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var PrimeAgriculturalAreasLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        interactivity: ''
      }
    }

  });

  return PrimeAgriculturalAreasLayer;

});
