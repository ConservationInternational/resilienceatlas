define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/greenlands_cartocss.cartocss',
  'text!views/map/layers/sql/greenlands_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var GreenlandsLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return GreenlandsLayer;

});