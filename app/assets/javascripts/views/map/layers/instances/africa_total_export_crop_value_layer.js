define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/africa_total_export_crop_value_cartocss.cartocss',
  'text!views/map/layers/sql/africa_total_export_crop_value_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var AfricaTotalExportCropValueLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: '168.474 million US$',
          max: '466119.747 million US$',
          bucket: [
            '#EDF8FB',
            '#B2E2E2',
            '#66C2A4',
            '#2CA25F',
            '#006D2C'
          ]
        }
      }
    }

  });

  return AfricaTotalExportCropValueLayer;

});
