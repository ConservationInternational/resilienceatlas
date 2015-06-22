define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/welland_canal_cartocss.cartocss',
  'text!views/map/layers/sql/welland_canal_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var WellandCanalLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });
  
  return WellandCanalLayer;

});