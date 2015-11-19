(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.AnalysisPageView = Backbone.View.extend({

    defaults: {
      elAnalysis: '.m-analysis',
      elWidgets: '.widgets',
      category: '',
      iso: '',
      country: ''
    },

    events: {
      'click .btn-back-analysis': 'hideAnalysis',
      'click .btn-analysis-info' : '_showInfo'
    },

    template: HandlebarsTemplates['analysis/analysis_page_tpl'],

    widgets: {
      'bar_chart': 'initBarChart',
      'line_chart': 'initLineChart',
      'multi_line_chart': 'initMultiLineChart',
      'number': 'initNumber',
      'text_list': 'initTextList',
      'bar_line_chart': 'initBarLineChart',
      'group_bar_chart': 'initGroupBarChart',
      'group_horizontal_bar_chart': 'initGroupHorizontalBarChart',
      'pyramid_chart': 'initPyramidChart'
    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.category = this.options.category;
      this.iso = this.options.iso;
      this.country = this.options.country;
      this.data = this.options.data;

      this.infowindow = new root.app.View.InfoWindow;
      this.render();
    },

    render: function() {
      this.$el.html(this.template({
        category: this.data.category_name,
        country: this.country
      }));

      $(this.defaults.elAnalysis).addClass('visible');
      $('body').addClass('analyzing');

      this.initializeWidgets();

      Backbone.Events.trigger('map:redraw');
    },

    initializeWidgets: function() {
      var self = this;

      _.sortBy(this.data.indicators, function(indicator) {
        return indicator.name;
      });

      _.each(this.data.indicators, function(indicator) {
        var widget = indicator.widget;
        var widgetInstance = self.widgets[widget];

        if(widgetInstance) {
          self[widgetInstance](indicator);
        }
      });
    },

    hideAnalysis: function() {
      $(this.defaults.elAnalysis).removeClass('visible');
      $('body').removeClass('analyzing'); 
    },

    _showInfo: function(e) {
      e.preventDefault();
      var data = $(e.currentTarget).data('info');
      var name = $(e.currentTarget).data('name');

      this.infowindow.render(data, name);
    },

    initBarChart: function(indicator) {
      var barChart = new root.app.View.WidgetBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        unitZ: null,
        hasLine: false,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initGroupBarChart: function(indicator) {
      var groupBarChart = new root.app.View.WidgetGroupBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        labels: indicator.labels,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initGroupHorizontalBarChart: function(indicator) {
      var horizontalBarChart = new root.app.View.WidgetGroupHorizontalBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initBarLineChart: function(indicator) {
      var barLineChart = new root.app.View.WidgetBarChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        unitZ: indicator.unitZ,
        hasLine: true,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initLineChart: function(indicator) {
      var lineChart = new root.app.View.WidgetLineChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata,
      });
    },

    initMultiLineChart: function(indicator) {
      var lineChart = new root.app.View.WidgetMultiLineChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata,
        labels: indicator.labels
      });
    },

    initNumber: function(indicator) {
      var number = new root.app.View.WidgetNumber({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initTextList: function(indicator) {
      var number = new root.app.View.WidgetTextList({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    },

    initPyramidChart: function(indicator) {
      var pyramidChart = new root.app.View.WidgetPyramidChart({
        el: this.options.elWidgets,
        slug: indicator.slug,
        query: indicator.query,
        name: indicator.name,
        iso: this.iso,
        labels: indicator.labels,
        unit: indicator.unit,
        meta_short: indicator.meta_short,
        metadata: indicator.metadata
      });
    }
  });

})(this);