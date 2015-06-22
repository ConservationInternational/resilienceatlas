define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/oak_ridges_moraine_2002_cartocss.cartocss',
  'text!views/map/layers/sql/oak_ridges_moraine_2002_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var OakRidgesMoraineLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return OakRidgesMoraineLayer;

});