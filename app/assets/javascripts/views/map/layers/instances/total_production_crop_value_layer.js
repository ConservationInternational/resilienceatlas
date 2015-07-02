define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/total_production_crop_valuecartocss.cartocss',
  'text!views/map/layers/sql/total_production_crop_value_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var TotalProductionCropValueLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        legend: {
          min: '4604',
          max: '1056680',
          bucket: [
            '#FFFFCC',
            '#A1DAB4',
            '#41B6C4',
            '#2C7FB8',
            '#253494'
          ]
        }
      }
    }

  });

  return TotalProductionCropValueLayer;

});
