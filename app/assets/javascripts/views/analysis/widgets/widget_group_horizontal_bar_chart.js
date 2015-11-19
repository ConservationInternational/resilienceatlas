(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetGroupHorizontalBarChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-bar-chart'
    },

    bucket: ['#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C', '#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_group_horizontal_bar_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;

      root.app.View.WidgetGroupHorizontalBarChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      var legend = this.getLegendData();
      var graph = this.getGraphData();

      this.charts.buildGroupHorizontalBarsChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: graph,
        hover: true,
        loader: 'is-loading',
        interpolate: 'basis',
        hasLine: this.hasLine,
        bucket: this.bucket,
        margin: {
          top: 30,
          right: 20,
          bottom: 20,
          left: 50,
          xaxis: 10,
          tooltip: 1.8
        }
      });

      this.charts.buildLegend({
        elem: '#' + this.slug + '-legend',
        contentWidth: 300,
        data: legend,
        unit: '',
        decimals: 0
      });
    },

    getGraphData: function() {
      var categories = [];
      var series = [];
      var groups = _.groupBy(this.data, 'label');
      var dataByCategories = _.groupBy(this.data, 'category');
      var labels = _.keys(groups);

      labels = _.map(labels, function(label) {
        if(label.length > 11){
          label = label.substring(0, 9) + '...';
        }
        return label;
      });

      _.each(groups, function(group) {
        _.each(group, function(value) {
          if(!categories[value.category]) {
            categories[value.category] = [];
          }
          categories[value.category].push(value.value);
        });
      });

      for(var category in categories){
        series.push({
          label: category,
          values: _.flatten(categories[category])
        });
      }

      var data = {
        labels: labels,
        series: series
      };

      return data;
    },

    getLegendData: function() {
      var legendValues = [];
      var bucket = this.bucket;
      var categories = _.groupBy(this.data, 'category');
      var labels = _.keys(categories);

      _.each(labels, function(label, i) {
        legendValues.push({ name: label, color: bucket[i] });
      });
      return legendValues;
    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        return values;
      }
    }

  });

})(this);