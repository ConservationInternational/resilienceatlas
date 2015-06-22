define([
  'underscore',
  'backbone',
  //BOUNDARIES
  'views/map/layers/instances/upper_tier_municipalities_layer',
  'views/map/layers/instances/upper_tier_municipalities_labels_layer',
  'views/map/layers/instances/lower_tier_municipalities_layer',
  'views/map/layers/instances/lower_tier_municipalities_labels_layer',
  //SETTLEMENTS
  'views/map/layers/instances/settlement_area_layer',
  'views/map/layers/instances/urban_growth_centre_location_layer',
  'views/map/layers/instances/urban_growth_centre_detailed_layer',
  'views/map/layers/instances/built_up_area_layer',
  //ENVIRONMENTAL
  'views/map/layers/instances/greenlands_2004_layer',
  'views/map/layers/instances/watershed_boundaries_layer',
  'views/map/layers/instances/rivers_layer',
  'views/map/layers/instances/greenbelt_2005_layer',
  'views/map/layers/instances/niagara_escarpment_plan_1973_layer',
  'views/map/layers/instances/oak_ridges_moraine_2002_layer',
  'views/map/layers/instances/protected_countryside_layer',
  'views/map/layers/instances/lake_simcoe_protection_2009_layer',
  //TRANSPORTATION
  'views/map/layers/instances/roads_layer',
  'views/map/layers/instances/subway_layer',
  'views/map/layers/instances/railway_layer',
  'views/map/layers/instances/commuter_rail_stations_layer',
  'views/map/layers/instances/international_airport_layer',
  'views/map/layers/instances/welland_canal_layer',
  'views/map/layers/instances/intermodal_terminals_layer',
  'views/map/layers/instances/major_ports_layer',
  //CONTEXT
  'views/map/layers/instances/prime_agricultural_areas_layer',
  'views/map/layers/instances/niagara_peninsula_grape_lands_layer',
  'views/map/layers/instances/holland_marsh_layer',
  'views/map/layers/instances/whitebelt_lands_layer'
], function(_,
  Backbone,
  //BOUNDARIES
  UpperTierMunicipalitiesLayer,
  UpperTierMunicipalitiesLabelsLayer,
  LowerTierMunicipalitiesLayer,
  LowerTierMunicipalitiesLabelsLayer,
  //SETTLEMENTS
  SetlementAreaLayer,
  UrbanGrowthCentreLocationLayer,
  UrbanGrowthCentreDetailedLayer,
  BuiltUpAreaLayer,
  //ENVIRONMENTAL
  GreenlandsLayer,
  WatershedBoundariesLayer,
  RiversLayer,
  GreenbeltLayer,
  NiagaraEscarpmentPlanLayer,
  OakRidgesMoraineLayer,
  ProtectedCountrysideLayer,
  LakeSimcoeProtectionLayer,
  //TRANSPORTATION
  RoadsLayer,
  SubwayLayer,
  RailwayLayer,
  CommuterRailStationsLayer,
  InternationalAirportLayer,
  WellandCanalLayer,
  IntermodalTerminalsLayer,
  MajorPortsLayer,
  //CONTEXT
  PrimeAgriculturalAreasLayer,
  NiagaraPeninsulaGrapeLandsLayer,
  HollandMarshLayer,
  WhitebeltLandsLayer
  ){

  'use strict';

  var layersInstances = [
    //BOUNDARIEs
    { slug: 'upper_tier_municipalities_layer', Instance: UpperTierMunicipalitiesLayer },
    { slug: 'upper_tier_municipalities_labels', Instance: UpperTierMunicipalitiesLabelsLayer },
    { slug: 'lower_tier_municipalities_layer', Instance: LowerTierMunicipalitiesLayer },
    { slug: 'lower_tier_municipalities_labels', Instance: LowerTierMunicipalitiesLabelsLayer },
    //SETTLEMENTS
    { slug: 'settlement_area', Instance: SetlementAreaLayer },
    { slug: 'urban_growth_centre_location', Instance: UrbanGrowthCentreLocationLayer },
    { slug: 'urban_growth_centre_detailed', Instance: UrbanGrowthCentreDetailedLayer },
    { slug: 'built_up_area', Instance: BuiltUpAreaLayer },
    //ENVIRONMENTAL
    { slug: 'greenlands_2004', Instance: GreenlandsLayer },
    { slug: 'watershed_boundaries', Instance: WatershedBoundariesLayer },
    { slug: 'rivers', Instance: RiversLayer },
    { slug: 'greenbelt_2005', Instance: GreenbeltLayer },
    { slug: 'niagara_escarpment_plan_1973', Instance: NiagaraEscarpmentPlanLayer },
    { slug: 'oak_ridges_moraine_2002', Instance: OakRidgesMoraineLayer },
    { slug: 'protected_countryside', Instance: ProtectedCountrysideLayer },
    { slug: 'lake_simcoe_protection_2009', Instance: LakeSimcoeProtectionLayer },
    //TRANSPORTATION
    { slug: 'roads', Instance: RoadsLayer },
    { slug: 'subway', Instance: SubwayLayer },
    { slug: 'railway', Instance: RailwayLayer },
    { slug: 'commuter_rail_stations', Instance: CommuterRailStationsLayer },
    { slug: 'international_airport', Instance: InternationalAirportLayer },
    { slug: 'welland_canal', Instance: WellandCanalLayer },
    { slug: 'intermodal_terminals', Instance: IntermodalTerminalsLayer },
    { slug: 'major_ports', Instance: MajorPortsLayer },
    //CONTEXT
    { slug: 'prime_agricultural_areas', Instance: PrimeAgriculturalAreasLayer },
    { slug: 'niagara_peninsula_grape_lands', Instance: NiagaraPeninsulaGrapeLandsLayer },
    { slug: 'holland_marsh', Instance: HollandMarshLayer },
    { slug: 'whitebelt_lands', Instance: WhitebeltLandsLayer }
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
