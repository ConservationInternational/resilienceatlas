//= require jquery
//= require jquery_ujs
//= require jquery-ui/sortable
//= require jquery-ui-touch-punch-valid
//= require underscore
//= require backbone
//= require handlebars
//= require slick-carousel
//= require foundation
//= require d3

//= require ./helpers/handlebars_helpers
//= require ./helpers/class
//= require ./helpers/cartodb_layer
//= require ./helpers/cartodb_raster
//= require ./helpers/cartodb_mask
//= require ./helpers/charts
//= require_tree ./models
//= require_tree ./collections
//= require_tree ./templates
//= require_tree ./views/common
//= require_tree ./views/map
//= require_tree ./views/journeys
//= require_tree ./views/static
//= require ./views/analysis/widgets/widget_view
//= require ./views/analysis/widgets/widget_bar_chart
//= require ./views/analysis/widgets/widget_line_chart
//= require ./views/analysis/widgets/widget_number
//= require ./views/analysis/widgets/widget_text_list
//= require ./views/analysis/analysis_page_view
//= require ./views/analysis/analysis_selectors_view

//= require router

(function(root) {

  'use strict';

  /**
   * Provide top-level namespaces for our javascript.
   * @type {Object}
   */
  root.app = root.app || {
    Model: {},
    Collection: {},
    View: {},
    Helper: {}
  };

  /**
   * Main Application View
   */
  root.app.AppView = Backbone.View.extend({

    /**
     * Main DOM element
     * @type {Object}
     */
    el: document.body,

    initialize: function() {
      this.currentViews = [];
      this.router = new root.app.Router();
      this.initGlobalViews();
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.router, 'route:welcome', this.welcomePage);

      // Initializing map
      this.listenTo(this.router, 'route:map', this.mapPage);

      // Initializing journeys
      this.listenTo(this.router, 'route:journeys', this.journeysPage);

      // Initializing journeys
      this.listenTo(this.router, 'route:about', this._aboutPage)
    },

    initGlobalViews: function() {
      var journeysIndexCollection = new root.app.Collection.JourneysIndex();
      var headerView = new root.app.View.Header({
        el: '#headerView',
        journeys: journeysIndexCollection
      });

      // Fetching data
      var complete = _.invoke([
        journeysIndexCollection,
      ], 'fetch');

      $.when.apply($, complete).done(function() {
        headerView.render();
        this.totalJourneys = journeysIndexCollection.length;
      }.bind(this));
    },

    welcomePage: function() {
      var sliderView = new root.app.View.Slider({
        el: '#sliderView'
      });
    },

    mapPage: function() {
      var journeyMap = this._checkJourneyMap();
      var toolbarView = new root.app.View.Toolbar();
      var layersGroupsCollection = new root.app.Collection.LayersGroups();
      var layersCollection = new root.app.Collection.Layers();
      var mapModel = new (Backbone.Model.extend({
          defaults: {
            journeyMap: journeyMap,
            countryIso: this.router.params.attributes.countryIso ? this.router.params.attributes.countryIso : null
          }
        }));

      var mapView = new root.app.View.Map({
        el: '#mapView',
        layers: layersCollection,
        basemap: this.router.params.attributes.basemap,
        model: mapModel,
        router: this.router,
        options: {
          map: {
            zoom: this.router.params.attributes.zoom || 3,
            center: this.router.params.attributes.center ? [ JSON.parse(this.router.params.attributes.center).lat, JSON.parse(this.router.params.attributes.center).lng] : [0, 15],
            zoomControl: false,
            scrollWheelZoom: false
          }
        }
      });

      //No Layer list nor legend are showed into journey embed map.
      if (!journeyMap) {
        var layersListView = new root.app.View.LayersList({
          el: '#layersListView',
          layers: layersCollection
        });

        var legendView = new root.app.View.Legend({
          el: '#legendView',
          layers: layersCollection,
          model: new (Backbone.Model.extend({
            defaults: {
              hidden: false,
              order: []
            }
          })),
        });
      }

      // At begining create a map
      mapView.createMap();

      // Fetching data
      var complete = _.invoke([
        layersGroupsCollection,
        layersCollection
      ], 'fetch');

      $.when.apply($, complete).done(function() {

        // Checking routes and setting actived layers
        var routerParams = _.isEmpty(this.router.params.attributes);
        if (!routerParams && this.router.params.attributes.layers) {
          var activedLayers = JSON.parse(this.router.params.attributes.layers);
          var activedLayersIds = _.pluck(activedLayers, 'id');
          _.each(layersCollection.models, function(model) {
            var routerLayer = _.findWhere(activedLayers, { id: model.id });
            var active = _.contains(activedLayersIds, model.id);
            var layerData = { active: active };
            if (routerLayer) {
              layerData.opacity = routerLayer.opacity;
              layerData.order = routerLayer.order;
            }
            model.set(layerData, { silent: true });
          });
          layersCollection.sort();
        } else if (routerParams) {
          var data = layersCollection.getActived();
          this.router.setParams('layers', data, ['id', 'opacity', 'order']);
        }

        // Updating URL when layers collection change
        layersCollection.on('change', function() {
          var data = layersCollection.getActived();
          this.router.setParams('layers', data, ['id', 'opacity', 'order']);
        }.bind(this));

        // Attach groups to layers collection
        layersCollection.setGroups(layersGroupsCollection);

        // Render views
        mapView.renderLayers();
        //Layer list is not showed into journey embed map.
        if (!journeyMap) {
          layersListView.render();
          legendView.render();
        }

        var socialShare = new root.app.View.Share({
          'map': mapView,
          layers: layersCollection
        });

        if (!journeyMap) {
          var searchView = new root.app.View.Search({
            el: '#toolbarView'
          });
        }
      }.bind(this));
    },

    journeysPage: function(journeyId) {
      //Expected route journeys/:journeyId?&step=4
      var journeyModel = new root.app.Model.Journeys();
      var journeysCollection = new root.app.Collection.Journeys();

      //Get router params
      var routerParams = this.router.params.attributes;

      if (!routerParams.step) {
        routerParams.step = 0;
      }

      //Fetching data
      var complete = _.invoke([
        journeysCollection
      ], 'getByParams', journeyId);

      //Starting view
      $.when.apply($, complete).done(function() {
        var journeyView = new root.app.View.Journeys({
          model: journeyModel,
          journey: journeysCollection,
          totalJourneys: this.totalJourneys,
          currentStep: routerParams.step
        });
      }.bind(this));

      //Telling router to be aware of this model changes
      journeyModel.on('change', function() {
        var currentStep = journeyModel.get('step');
        this.router.setParams('step', currentStep);
      }.bind(this));
    },

    _checkJourneyMap: function() {
      return $('body').hasClass('is-journey-map');
    },

    start: function() {
      Backbone.history.start({ pushState: true });
    },

    _aboutPage: function() {
      new root.app.View.StaticPage;
    }

  });

  new app.AppView().start();

})(this);
