define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/urban_growth_centre_detailed_cartocss.cartocss',
  'text!views/map/layers/sql/urban_growth_centre_detailed_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var UrbanGrowthCentreDetailedLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return UrbanGrowthCentreDetailedLayer;

});