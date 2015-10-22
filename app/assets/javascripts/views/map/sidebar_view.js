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

      this.render();
    },

    render: function() {
      var self = this;

      this.$el.html(this.template);

      $(document).foundation('tab', 'reflow');

      $('#sidebarTabs').on('toggled', function (event, tab) {
        self.switchTabs(tab);
      });
    },

    switchTabs: function(tab) {
      var $tab = $(tab);
      var section = $tab.data('section');

      if(section === 'analysis') {
        $('body').addClass('analysis-section');
        this.initAnalysis();
      } else {
        $('body').removeClass('analysis-section');
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
