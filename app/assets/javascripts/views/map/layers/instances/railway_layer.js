define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/railway_cartocss.cartocss',
  'text!views/map/layers/sql/railway_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var RailwayLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return RailwayLayer;

});