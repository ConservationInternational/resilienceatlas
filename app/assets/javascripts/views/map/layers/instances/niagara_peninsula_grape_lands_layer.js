define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/niagara_peninsula_grape_lands_cartocss.cartocss',
  'text!views/map/layers/sql/niagara_peninsula_grape_lands_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var NiagaraPeninsulaGrapeLandsLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return NiagaraPeninsulaGrapeLandsLayer;

});