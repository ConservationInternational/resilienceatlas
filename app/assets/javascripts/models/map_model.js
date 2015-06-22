define([
  'backbone'
], function(Backbone) {

  'use strict';

  var MapModel = Backbone.Model.extend({

    defaults: {
      basemap: null,
      loadQueue: []
    },

    validate: function(attr) {
      // Basemap only can be topography, satellite or terrain
      if (attr.basemap !== 'topography' &&
        attr.basemap !== 'satellite' &&
        attr.basemap !== 'terrain') {
        return 'Incorrect basemap';
      }
    }

  });

  return MapModel;

});
