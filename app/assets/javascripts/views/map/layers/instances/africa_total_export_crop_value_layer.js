define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_total_export_crop_value_cartocss.cartocss',
  'text!views/map/layers/sql/africa_total_export_crop_value_sql.pgsql'
], function($, _, URI, CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaTotalExportCropValueLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return AfricaTotalExportCropValueLayer;

});