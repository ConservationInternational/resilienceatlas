//= require jquery
//= require jquery_ujs
//= require underscore
//= require backbone
//= require handlebars

//= require ./helpers/class
//= require ./helpers/cartodb_layer
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
    },

    mapPage: function() {
      this.removeViews();

      var layersGroupsCollection = new root.app.Collection.LayersGroups();
      var layersCollection = new root.app.Collection.Layers();

      var mapView = new root.app.View.Map({
        el: '#mapView',
        layers: layersCollection
      });

      var layersListView = new root.app.View.LayersList({
        el: '#layersListView',
        collection: layersCollection
      });

      // At begining create a map and fetch layers to show
      mapView.createMap();

      // Fetching data
      var complete = _.invoke([
        layersGroupsCollection,
        layersCollection
      ], 'fetch');

      $.when.apply($, complete).done(function() {

        var routerParams = _.isEmpty(this.router.params.attributes);

        if (!routerParams && this.router.params.attributes.layers) {
          var activedLayers = JSON.parse(this.router.params.attributes.layers);
          var activedLayersIds = _.pluck(activedLayers, 'id');
          _.each(layersCollection.models, function(model) {
            var active = _.contains(activedLayersIds, model.id);
            model.set('active', active, { silent: true });
          });
        } else if (routerParams) {
          var data = layersCollection.getActived();
          this.router.setParams('layers', data, ['id', 'opacity', 'order']);
        }

        layersCollection.setGroups(layersGroupsCollection);

        mapView.renderLayers();
        layersListView.render();

      }.bind(this));

      // Updating URL when layers change
      layersCollection.on('change', function() {
        var data = layersCollection.getActived();
        this.router.setParams('layers', data, ['id', 'opacity', 'order']);
      }.bind(this));

      this.currentViews = [ mapView, layersListView ];
    },

    removeViews: function() {
      _.each(this.currentViews, function(view) {
        view.remove();
      });
    },

    start: function() {
      Backbone.history.start({ pushState: true });
    }

  });

  new app.AppView().start();

})(this);
