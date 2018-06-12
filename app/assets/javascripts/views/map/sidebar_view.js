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
      this.analysisPanel = $('.analysis-panel');
    },

    setListeners: function() {
      // When the width or status of the sidebar changes,
      // we trigger the offset
      this.sidebar.on('transitionend', function(e) {
        if (e.target === this.sidebar[0] || e.target === this.analysisPanel[0]) {
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
      $('.btn-sidebar-toggle').on('click', _.bind(this.collapsePanel, this));
      $('.btn-analysis-panel-expand').on('click', _.bind(this.expandAnalysisPanel, this));
      $('.btn-analysis-panel-contract').on('click', _.bind(this.contractAnalysisPanel, this));
    },

    collapsePanel: function() {
      // We collapse/expand the sidebar
      this.sidebar.toggleClass('is-collapsed');
    },

    /**
     * Expand the analysis panel
     */
    expandAnalysisPanel: function () {
      this.sidebar.addClass('analyzing');
      if (!this.analysisView) {
        if (!this.section || this.section === 'layers') {
          this.analysisView = new root.app.View.analysisSelectors();
        } else {
          this.analysisView = new root.app.View.analysisModel();
        }
      }
    },

    /**
     * Contract the analysis panel
     */
    contractAnalysisPanel: function () {
      this.sidebar.removeClass('analyzing');
    },

    /**
     * Trigger an event to tell the map how
     * much to offset depending on the visibility
     * of the sidebar and its width
     */
    triggerSidebarOffset: function() {
      var sidebarIsCollapsed = this.sidebar.hasClass('is-collapsed');
      var sidebarWidth = this.sidebar.width();
      var analysisPanelIsCollapsed = !this.sidebar.hasClass('analyzing');
      var analysisPanelWidth = this.analysisPanel.width();

      var offset = (!sidebarIsCollapsed ? sidebarWidth : 0) +
        (!analysisPanelIsCollapsed ? analysisPanelWidth : 0);

      // We offset the map's center
      Backbone.Events.trigger('map:offset', [offset, 0]);
    },

    setThemeColor: function() {
      $('.theme-color').css({'color': this.subdomainParams.color});
      $('.theme-bg-color').css({'background-color': this.subdomainParams.color});
    },

    switchTabs: function(tab) {
      var $tab = $(tab);
      var section = $tab.data('section');

      if (!this.section || this.section !== section) {
        this.contractAnalysisPanel();
        this.section = section;
        if (this.analysisView) {
          this.analysisView.destroy();
          this.analysisView = null;
        }
      }
    }
  });

})(this);
