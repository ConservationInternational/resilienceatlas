//= require jquery2
//= require jquery_ujs
//= require underscore
//= require backbone
//= require leaflet

//= require ./helpers/class
//= require ./helpers/cartodb_layer
//= require_tree ./collections
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
      var mapView = new root.app.View.Map({ el: '#mapView' });
      mapView.createMap();
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
