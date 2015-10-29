(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetGroupBarChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-bar-chart'
    },

    bucket: ['#D8D8D8', '#0088CE', '#65C1EE', '#43AB3C', '#D8D8D8', '#0088CE', '#65C1EE', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_group_bar_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;

      root.app.View.WidgetGroupBarChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      var legend = this.getLegendData();

      this.charts.buildGroupBarsChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: this.data,
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
        contentHeight: 80,
        data: legend,
        unit: '',
        decimals: 0
      });
    },

    getLegendData: function() {
      var self = this;
      var legendValues = [];
      var bucket = this.bucket;

      if(this.data && this.data[0]) {
        var keys = _.keys(this.data[0]);
        var values = _.without(keys, 'x');

        _.each(values, function(value, i) {
          if(self.labels) {
            value = self.labels[value];
          }
          legendValues.push({ name: value, color: bucket[i] });
        });
      }

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