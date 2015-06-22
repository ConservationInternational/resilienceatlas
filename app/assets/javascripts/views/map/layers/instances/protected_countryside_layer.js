define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/protected_countryside_cartocss.cartocss',
  'text!views/map/layers/sql/protected_countryside_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var ProtectedCountrysideLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        interactivity: ''
      }
    }

  });

  return ProtectedCountrysideLayer;

});