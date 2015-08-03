//= require jquery2
//= require jquery_ujs
//= require underscore
//= require backbone
//= require leaflet
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

      var layersCollection = new root.app.Collection.Layers();
      var mapView = new root.app.View.Map({
        el: '#mapView',
        collection: layersCollection
      });
      var layersListView = new root.app.View.LayersList({
        el: '#layersListView',
        collection: layersCollection
      });

      // At begining create a map and fetch layers to show
      mapView.createMap();
      layersCollection.fetch();

      this.currentViews = [ mapView ];
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
