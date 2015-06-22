define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/intermodal_terminals_cartocss.cartocss',
  'text!views/map/layers/sql/intermodal_terminals_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var IntermodalTerminalsLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return IntermodalTerminalsLayer;

});