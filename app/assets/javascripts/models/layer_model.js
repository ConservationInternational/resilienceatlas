define([
  'underscore',
  'backbone',
   //CONFLICTS
  'views/map/layers/instances/overall_gpi_scores_layer',
  //FOOD SECURITY
  'views/map/layers/instances/africa_livelihoodzones_layer'
], function(_,
  Backbone,
   //CONFLICTS
  OverallGpiScoresLayer,
  //FOOD SECURITY
  AfricaLivelihoodZonesLayer
  ){

  'use strict';

  var layersInstances = [
    //CONFLICTS
    { slug: 'overall_gpi_scores', Instance: OverallGpiScoresLayer},
    { slug: 'africa_livelihoodzones', Instance: AfricaLivelihoodZonesLayer}
  ];

  var LayerModel = Backbone.Model.extend({

    defaults: {
      groupActive: false,
      groupName: null,
      groupOrder: 0,
      groupSlug: null,
      groupInfo: null,
      groupLayer: false,
      layerGroup: null,
      name: null,
      slug: null,
      type: null,
      category: null,
      zindex: 0,
      opacity: 1,
      active: false,
      timeline: false,
      info: null,
      interactivity: null,
      locateLayer: null,
      Instance: null
    },

    initialize: function() {
      this.attachInstance();
    },

    attachInstance: function() {
      var layer = _.findWhere(layersInstances, {
        slug: this.attributes.slug
      });
      if (layer) {
        this.attributes.Instance = layer.Instance;
      }
    },

    validate: function(attr) {
      if (typeof attr.active !== 'boolean') {
        return 'Incorrect attribute';
      }
    }

  });

  return LayerModel;

});
