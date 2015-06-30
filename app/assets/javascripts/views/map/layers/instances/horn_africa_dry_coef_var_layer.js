define([
  'views/map/layers/layouts/cartodb_layer',
  'text!views/map/layers/cartocss/horn_africa_dry_coef_var_cartocss.cartocss',
  'text!views/map/layers/sql/horn_africa_dry_coef_var_sql.pgsql'
], function(CartoDBLayer, CartoCSS, SQL) {

  'use strict';

  var HornAfricaDryCoefChangeLayer = CartoDBLayer.extend({

    options: {
      params: {
        q: SQL,
        cartocss: CartoCSS,
        type: ''
      }
    }

  });

  return HornAfricaDryCoefChangeLayer;

});
