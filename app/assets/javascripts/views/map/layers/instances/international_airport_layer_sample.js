define([
  'views/map/layers/layouts/native_layer',
  'text!views/map/layers/sql/international_airport_sql.pgsql'
], function(NativeLayer, SQL) {

  'use strict';

  var InternationalAirportLayer = NativeLayer.extend({

    options: {
      params: {
        q: SQL,
        type: 'geojson'
      }
    }

  });

  return InternationalAirportLayer;

});
