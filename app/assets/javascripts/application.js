//= require jquery
//= require jquery_ujs
//= require jquery-ui/sortable
//= require jquery-ui-touch-punch-valid
//= require underscore
//= require backbone
//= require handlebars
//= require slick-carousel
//= require foundation

//= require ./helpers/handlebars_helpers
//= require ./helpers/class
//= require ./helpers/cartodb_layer
//= require ./helpers/cartodb_raster
//= require ./helpers/cartodb_mask
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
      this.listenTo(this.router, 'route:about', this.aboutPage)
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
      var mapPageView = new root.app.MapPageView({
        router: this.router, 
      });
    },

    journeysPage: function(journeyId) {
      var journeyPageView = new root.app.JourneysPageView({
        router: this.router, 
        options: {
          'journeyId': journeyId,
          'totalJourneys': this.totalJourneys
        }
      });
    },

    aboutPage: function() {
      new root.app.View.StaticPageView;
    },

    start: function() {
      Backbone.history.start({ pushState: true });
    }
  });

  new app.AppView().start();

})(this);
