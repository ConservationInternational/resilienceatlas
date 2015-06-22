define([
  'jquery',
  'underscore',
  'uri/URI',
  'views/map/layers/layouts/native_layer',
  'text!views/map/layers/sql/international_airport_sql.pgsql'
], function($, _, URI, NativeLayer, SQL) {

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
