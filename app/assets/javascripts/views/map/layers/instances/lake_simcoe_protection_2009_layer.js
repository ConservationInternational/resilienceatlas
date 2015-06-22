define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/lake_simcoe_protection_2009_cartocss.cartocss',
  'text!views/map/layers/sql/lake_simcoe_protection_2009_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var LakeSimcoeProtectionLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return LakeSimcoeProtectionLayer;

});