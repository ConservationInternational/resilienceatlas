(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Sidebar = Backbone.View.extend({

    el: '#sidebarView',

    template: HandlebarsTemplates['map/sidebar_tpl'],

    events: {
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.subdomainParams = settings.subdomainParams;
      this.setVars();
      this.setListeners();
      this.triggerSidebarOffset();
      this.render();
    },

    setVars: function() {
      this.sidebar = $('.l-sidebar--fullscreen');
    },

    setListeners: function() {
      // When the width or status of the sidebar changes,
      // we trigger the offset
      this.sidebar.on('transitionend', function(e) {
        if (e.target === e.currentTarget) {
          this.triggerSidebarOffset();
        }
      }.bind(this));
    },

    render: function() {
      var self = this;

      this.$el.html(this.template({ analysis: this.subdomainParams && this.subdomainParams.has_analysis }));

      $(document).foundation('tab', 'reflow');

      $('#sidebarTabs').on('toggled', function (event, tab) {
        self.switchTabs(tab);
      });

      this.subdomainParams && this.setThemeColor();
      $('.btn-dash-switcher').on('click', _.bind(this.collapsePanel, this))
    },

    collapsePanel: function() {
      // We collapse/expand the sidebar
      this.sidebar.toggleClass('is-collapsed');
    },

    /**
     * Trigger an event to tell the map how
     * much to offset depending on the visibility
     * of the sidebar and its width
     */
    triggerSidebarOffset: function() {
      var isCollapsed = this.sidebar.hasClass('is-collapsed');
      var sidebarWidth = this.sidebar.width();

      // We offset the map's center
      Backbone.Events.trigger('map:offset', [
        !isCollapsed ? sidebarWidth : 0,
        0
      ]);
    },

    setThemeColor: function() {
      $('.theme-color').css({'color': this.subdomainParams.color});
      $('.theme-bg-color').css({'background-color': this.subdomainParams.color});
    },

    switchTabs: function(tab) {
      var $tab = $(tab);
      var section = $tab.data('section');

      if(section === 'analysis') {
        $('body').addClass('analysis-section');
        Backbone.Events.trigger('map:toggle:layers', false);
        this.initAnalysis();
      } else {
        $('body').removeClass('analysis-section');
        Backbone.Events.trigger('map:toggle:layers', true);
        this.hideAnalysis();
      }
    },

    initAnalysis: function() {
      if(this.analysisView) {
        this.analysisView.closeAnalysis();
      } else {
        this.analysisView = new root.app.View.analysisSelectors();
      }
    },

    hideAnalysis: function() {
      if(this.analysisView) {
        this.analysisView.closeAnalysis();
      }
    }
  });

})(this);
