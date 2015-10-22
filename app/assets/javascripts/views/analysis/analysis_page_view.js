(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.AnalysisPageView = Backbone.View.extend({

    defaults: {
      elAnalysis: '.m-analysis',
      elWidgets: '#widgets',
      category: 'stressors',
      iso: 'DJI'
    },

    el: 'body',

    template: HandlebarsTemplates['analysis/analysis_page_tpl'],

    widgets: {
      'bar_chart': 'initBarChart',
      'line_chart': 'initLineChart',
      'number': 'initNumber',
      'text_list': 'initTextList',
      'bar_line_chart': 'initBarLineChart'
    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.category = this.options.category;
      this.iso = this.options.iso;
      this.render();
    },

    render: function() {
      this.$el.append(this.template({
        categories: this.data
      }));

      this.initializeWidgets();
    },

    initializeWidgets: function() {
      var self = this;

      _.each(this.data.indicators, function(indicator) {
        var widget = indicator.widget;
        var widgetInstance = self.widgets[widget];

        if(widgetInstance) {
          self[widgetInstance](indicator);
        }
      });
    },

    initBarChart: function(indicator) {
      var barChart = new root.app.View.WidgetBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso
      });
    },

    initBarLineChart: function(indicator) {
      var barLineChart = new root.app.View.WidgetBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        hasLine: true
      });
    },

    initLineChart: function(indicator) {
      var lineChart = new root.app.View.WidgetLineChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso
      });
    },

    initNumber: function(indicator) {
      var number = new root.app.View.WidgetNumber({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso
      });
    },

    initTextList: function(indicator) {
      var number = new root.app.View.WidgetTextList({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso
      });
    }
  });

})(this);