define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/flood_return_period_cartocss.cartocss',
  'text!views/map/layers/sql/flood_return_period_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var FloodRetunPeriodLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: '',
        raster: true,
        legend: {
          min: 'less',
          max: 'more',
          type: 'choropleth',
          bucket: [
            '#007FFE',
            '#419FFE',
            '#7DBEFE',
            '#FEF1CB',
            '#FEA5A5',
            '#FF7A7A',
            '#FF4D4D'
          ]
        }
      }
    }

  });

  return FloodRetunPeriodLayer;

});