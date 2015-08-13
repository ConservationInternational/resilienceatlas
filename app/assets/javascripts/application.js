//= require jquery
//= require jquery_ujs
//= require underscore
//= require backbone
//= require handlebars
//= require jquery-ui/sortable

//= require ./helpers/class
//= require ./helpers/cartodb_layer
//= require_tree ./models
//= require_tree ./collections
//= require_tree ./templates
//= require_tree ./views
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
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.router, 'route:welcome', function() {
        console.log('You are in Homepage.');
      });

      // Initializing map
      this.listenTo(this.router, 'route:map', this.mapPage);

      // Initializing journeys
      this.listenTo(this.router, 'route:journeys', this.journeysPage)
    },

    mapPage: function() {
      var layersGroupsCollection = new root.app.Collection.LayersGroups();
      var layersCollection = new root.app.Collection.Layers();

      var mapView = new root.app.View.Map({
        el: '#mapView',
        layers: layersCollection
      });

      var layersListView = new root.app.View.LayersList({
        el: '#layersListView',
        layers: layersCollection
      });

      var legendView = new root.app.View.Legend({
        el: '#legendView',
        layers: layersCollection
      });

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
        layersListView.render();
        legendView.render();

      }.bind(this));
    },

    journeysPage: function() {
      //Expected route journeys?journey=1&step=4

      var journeyModel = new root.app.Model.Journeys();
      var journeysCollection = new root.app.Collection.Journeys();

      //Get router params
      var routerParams = this.router.params.attributes;

      if (!_.isEmpty(routerParams)) {
        //Fetching data
        var complete = _.invoke([
          journeysCollection
        ], 'getByParams', routerParams.journey);

        //Starting view
        $.when.apply($, complete).done(function() {
          var journeyView = new root.app.View.Journeys({
            model: journeyModel,
            journey: journeysCollection,
            currentStep: routerParams.step
          });
        }.bind(this));

        //Telling router to be aware of this model changes
        journeyModel.on('change', function() {
          var currentStep = journeyModel.get('step');
          this.router.setParams('step', currentStep);
        }.bind(this));

      }

    },

    start: function() {
      Backbone.history.start({ pushState: true });
    }

  });

  new app.AppView().start();

})(this);
