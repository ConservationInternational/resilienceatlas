define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/upper_tier_municipalities_cartocss.cartocss',
  'text!views/map/layers/sql/upper_tier_municipalities_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var UpperTierMunicipalitiesLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        interactivity: ''
      }
    }

  });

  return UpperTierMunicipalitiesLayer;

});