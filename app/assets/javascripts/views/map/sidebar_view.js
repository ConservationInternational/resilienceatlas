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
      this.render();
    },

    render: function() {
      var self = this;

      if ($('body').hasClass('.is-indicators') || $('body').hasClass('.is-atlas')) {
        this.subdomainParams.has_analysis = false;
      };
      this.$el.html(this.template({ analysis: this.subdomainParams && this.subdomainParams.has_analysis }));

      $(document).foundation('tab', 'reflow');

      $('#sidebarTabs').on('toggled', function (event, tab) {
        self.switchTabs(tab);
      });

      this.subdomainParams && this.setThemeColor();
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
      Backbone.Events.trigger('map:recenter');
    }
  });

})(this);
