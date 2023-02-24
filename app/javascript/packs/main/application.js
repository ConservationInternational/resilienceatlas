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
//= require ./helpers/xyz_tiles
//= require ./helpers/cartodb_mask
//= require ./helpers/charts
//= require_tree ./models
//= require_tree ./collections
//= require_tree ./templates
//= require ./views/mapPageView
//= require ./views/reportPageView
//= require ./views/staticPageView
//= require ./views/journeysPageView
//= require_tree ./views/common
//= require ./views/map/layers_list_view
//= require ./views/map/legend_view
//= require ./views/map/predictive_models_view
//= require ./views/map/map_view
//= require ./views/map/sidebar_view
//= require ./views/map/toolbar_view
//= require_tree ./views/journeys
//= require ./views/analysis/widgets/widget_view
//= require ./views/analysis/widgets/widget_bar_chart
//= require ./views/analysis/widgets/widget_group_bar_chart
//= require ./views/analysis/widgets/widget_group_horizontal_bar_chart
//= require ./views/analysis/widgets/widget_pyramid_chart
//= require ./views/analysis/widgets/widget_line_chart
//= require ./views/analysis/widgets/widget_multiLine_chart
//= require ./views/analysis/widgets/widget_number
//= require ./views/analysis/widgets/widget_text_list
//= require ./views/analysis/widgets/widget_scatter_chart
//= require ./views/analysis/widgets/widget_error_chart
//= require ./views/analysis/analysis_page_view
//= require ./views/analysis/analysis_selectors_view
//= require ./views/analysis/analysis_view

//= require router

function initApp(root) {

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
      // var subdomine = this._subdomineSettings();
      this.currentViews = [];

      var subomainParamsModel = new root.app.Model.Subdomain();
      subomainParamsModel.fetch().done(_.bind(function(){
        this.siteScopeId = subomainParamsModel.toJSON().data.id;
        this.setSubdomainParams(subomainParamsModel.toJSON().data.attributes);
        if (subomainParamsModel.toJSON().included && subomainParamsModel.toJSON().included.length > 0) {
          this.getPages(subomainParamsModel.toJSON().included);
        }
        this.initGlobalViews();
        this.router = new root.app.Router();
        this.setListeners();
        this.start();
      }, this));

      // Detecting language change
      if (typeof Transifex !== 'undefined') {
        Transifex.live.onTranslatePage(function(language_code) {
          if (window.currentLocation !== language_code) {
            window.currentLocation = language_code;
            const url = new URL(window.location.href);
            url.searchParams.set('locale', window.currentLocation);
            window.location.href = url.href;
          }
        });
      }
    },

    setSubdomainParams: function(data) {
      this.subdomainParams = {
        has_analysis: data.subdomain ? data.has_analysis : true,
        name: data.name || '',
        subdomain: data.subdomain || '',
        color: data.color || '#0089cc',
        header_theme: data.header_theme || '',
        lat: data.latitude || NaN,
        lng: data.longitude || NaN,
        zoom_level: data.zoom_level || NaN,
        link_text: data.linkback_text || null,
        link_url: data.linkback_url || null,
        header_color: data.header_color || null,
        logo_url: data.logo_url
      }

      this.setThemeColor();
      this.setIndicator();
    },

    setIndicator: function() {
      if (this.subdomainParams.subdomain) {
        $('body').addClass('is-indicators');
      }
    },

    setThemeColor: function() {
      //Main page items
      $('.theme-color').css({'color': this.subdomainParams.color});
      $('.btn-primary').css({'color': this.subdomainParams.color});
      $('.theme-bg-color').css({'background-color': this.subdomainParams.color});
      $('.m-explore').css({'background-color': this.subdomainParams.color});

      this.subdomainParams && this.subdomainParams.header_color && this.setHeaderColor();
      this.subdomainParams && this.subdomainParams.logo_url && this.setHeaderLogo();
      this.subdomainParams && this.subdomainParams.header_theme && this.setHeaderTheme();
      this.subdomainParams && this.subdomainParams.link_text && this.setLink();
    },

    setHeaderColor: function() {
      var color = this.hexToRgb(this.subdomainParams.header_color);
      $('.l-header-nav').css({'background-color': 'rgba('+color+', 0.7)'})
    },

    setHeaderTheme: function() {
      $('body').addClass('is-'+this.subdomainParams.header_theme);
    },

    setHeaderLogo: function() {
      $('.brand-area a').css({'background-image': 'url('+this.subdomainParams.logo_url+')'});
    },

    setLink: function() {
      var $link = $('.link-back');

      if ($link[0]) {
        this.subdomainParams.link_text && $link.attr('href', this.subdomainParams.link_url);
        this.subdomainParams.link_url && $link.html(this.subdomainParams.link_text);
      }
    },

    hexToRgb: function(hex) {
      var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
      return result ? parseInt(result[1], 16) +','+ parseInt(result[2], 16) +','+ parseInt(result[3], 16) : null;
    },

    getPages: function(data) {
      var pages = [];

      data.map(function(p){
        var page = {};
        page.id = p.id;
        page.title = p.attributes.title;
        page.url = p.attributes.url;
        page.priority = p.attributes.priority;

        pages.push(page);
        return pages;
      });

      pages = pages.sort(function(p){
        return p.priority
      }).reverse();
      this.subdomainParams.pages = pages;
    },

    setListeners: function() {
      this.listenTo(this.router, 'route:welcome', this.welcomePage);
      // Initializing map
      this.listenTo(this.router, 'route:map', this.mapPage);

      // Initializing embed map
      this.listenTo(this.router, 'route:mapEmbed', this.mapEmbedPage);

      // Initializing journeys
      this.listenTo(this.router, 'route:journeys', this.journeysPage);
      // Initializing about
      this.listenTo(this.router, 'route:about', this.aboutPage);
      // Initializing journeys index
      this.listenTo(this.router, 'route:journeysIndex', this.journeysIndexPage);

      this.listenTo(this.router, 'route:report', this.reportPage);
    },

    journeysIndexPage: function(){
      var journeysIndexCollection = new root.app.Collection.JourneysIndex();

      var journeyIndexView = new root.app.View.JourneysIndexView({
        journeys: journeysIndexCollection,
        subdomainParams: this.subdomainParams
      });

      // Fetching data
      var complete = _.invoke([
        journeysIndexCollection,
      ], 'fetch');

      $.when.apply($, complete).done(function() {
        journeyIndexView.render();
      }.bind(this));

    },

    initGlobalViews: function() {
      var journeysIndexCollection = new root.app.Collection.JourneysIndex();
      var headerView = new root.app.View.Header({
        el: '#headerView',
        journeys: journeysIndexCollection,
        subdomainParams: this.subdomainParams
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
        siteScopeId: this.siteScopeId,
        subdomainParams: this.subdomainParams
      });
    },

    reportPage: function() {
      var reportPageView = new root.app.ReportPageView({
        router: this.router,
        subdomainParams: this.subdomainParams,
        siteScopeId: this.siteScopeId
      });
    },

    mapEmbedPage: function() {
      var mapPageView = new root.app.MapPageView({
        router: this.router,
        siteScopeId: this.siteScopeId,
        embed: true
      });
    },

    journeysPage: function(journeyId) {
      var journeysIndexCollection = new root.app.Collection.JourneysIndex();

      // Fetching data
      var complete = _.invoke([
        journeysIndexCollection,
      ], 'fetch');

      $.when.apply($, complete).done(function() {
        var journeyPageView = new root.app.JourneysPageView({
          router: this.router,
          subdomainParams: this.subdomainParams,
          options: {
            'journeyId': journeyId,
            'totalJourneys': journeysIndexCollection.length
          }
        });
      }.bind(this));
    },

    aboutPage: function() {
      new root.app.View.StaticPageView({ subdomainParams: this.subdomainParams });
    },

    start: function() {
      Backbone.history.start({ pushState: true });
    }
  });

  new app.AppView();
}

$(document).on('ready', initApp.bind(this, window));
