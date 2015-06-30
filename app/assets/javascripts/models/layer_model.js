define([
  'underscore',
  'backbone',
   //CONFLICTS
  'views/map/layers/instances/overall_gpi_scores_layer',
  //FOOD SECURITY
  'views/map/layers/instances/africa_livelihoodzones_layer',
  //WATER
  'views/map/layers/instances/horn_africa_dry_coef_var_layer',
  //ECONOMY
  'views/map/layers/instances/africa_total_export_crop_value_layer',
  'views/map/layers/instances/total_production_crop_value_layer'
], function(_,
  Backbone,
   //CONFLICTS
  OverallGpiScoresLayer,
  //FOOD SECURITY
  AfricaLivelihoodZonesLayer,
  //WATER
  HornAfricaDryCoefChangeLayer,
  //ECONOMY
  AfricaTotalExportCropValueLayer,
  TotalProductionCropValueLayer
  ){

  'use strict';

  var layersInstances = [
    //CONFLICTS
    { slug: 'overall_gpi_scores', Instance: OverallGpiScoresLayer},
    { slug: 'africa_livelihoodzones', Instance: AfricaLivelihoodZonesLayer},
    { slug: 'horn_africa_dry_coef_var', Instance: HornAfricaDryCoefChangeLayer},
    { slug: 'total_export_crop_value', Instance: AfricaTotalExportCropValueLayer},
    { slug: 'total_production_crop_value', Instance: TotalProductionCropValueLayer}
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
