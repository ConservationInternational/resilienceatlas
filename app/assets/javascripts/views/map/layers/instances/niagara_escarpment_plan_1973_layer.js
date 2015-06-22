define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/niagara_escarpment_plan_1973_cartocss.cartocss',
  'text!views/map/layers/sql/niagara_escarpment_plan_1973_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var NiagaraEscarpmentPlanLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return NiagaraEscarpmentPlanLayer;

});