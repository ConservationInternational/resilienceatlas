define([
  'underscore',
  'backbone',
  'models/page_model',
  'collections/layers_collection',
  'collections/topics_collection',
  'collections/regions_collection',
  'views/map/map_view',
  'views/map/dashboard_navigation_view',
  'views/map/dashboard_view',
  'views/map/timeline_view',
  'views/map/legend_view',
  'views/map/analysis_view',
  'views/map/search_view',
  'views/map/toolbar_view',
  'text!data/layers.json'
], function(_, Backbone, PageModel, LayersCollection, TopicsCollection,
  RegionsCollection, MapView, DashboardNavigationView, DashboardView,
  TimelineView, LegendView, AnalysisView, SearchView, ToolbarView, layers) {

  'use strict';

  var MapPageView = Backbone.View.extend({

    initialize: function() {
      var layersData = JSON.parse(layers);
      this.model = new PageModel();
      this.layers = new LayersCollection(layersData, { validate: true, parse: true });
      this.topics = new TopicsCollection();
      this.regions = new RegionsCollection();
      this.setListeners();
      this.instanceModules();
    },

    setListeners: function() {
      this.listenTo(this.model, {
        'change:params': this.setParams
      }, this);
    },

    instanceModules: function() {

      this.map = new MapView({
        el: '#mapView',
        layers: this.layers,
        topics: this.topics
      });

      this.navigationDashboard = new DashboardNavigationView({
        el: '#navigationDashboard'
      });

      this.dashboard = new DashboardView({
        el: '#dashboardView',
        layers: this.layers,
        topics: this.topics,
        regions: this.regions,
        map: this.map
      });

      this.timeline = new TimelineView({
        el: '#timelineView',
        map: this.map
      });

      this.legend = new LegendView({
        el: '#legendView',
        layers: this.layers
      });

      this.analysis = new AnalysisView();

      this.search = new SearchView({
        el: '#searchView'
      });

      this.toolbar = new ToolbarView();
    },

    setParams: function() {
      this.navigationDashboard.setUrlParams(this.model.attributes.params);
      this.dashboard.setUrlParams(this.model.attributes.params);
    }

  });

  return MapPageView;

});
