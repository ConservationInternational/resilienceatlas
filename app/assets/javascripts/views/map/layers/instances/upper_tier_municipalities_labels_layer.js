define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/upper_tier_municipalities_labels_cartocss.cartocss',
  'text!views/map/layers/sql/upper_tier_municipalities_labels_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var UpperTierMunicipalitiesLabelsLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return UpperTierMunicipalitiesLabelsLayer;

});