(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetScatterChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-scatter-chart'
    },

    bucket: ['#D8D8D8', '#0088CE', '#65C1EE', '#43AB3C', '#D8D8D8', '#0088CE', '#65C1EE', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_scatter_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      
      root.app.View.WidgetScatterChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      var legend = this.getLegendData();

      this.charts.buildScatterChart({
        elem: '#' + this.slug + '-graph',
        data: this.data,
        hover: true,
        decimals: 0,
        loader: 'is-loading',
        unit: this.unit,
        unitY: this.unitY,
        unitX: this.unitX,
        margin: {
          top: 40,
          right: 40,
          bottom: 30,
          left: 55,
          xaxis: 10,
          tooltip: 2.2
        }
      });

      this.charts.buildLegend({
        elem: '#' + this.slug + '-legend',
        contentWidth: 300,
        data: legend,
        unit: '',
        decimals: 0,
        isCircle: true
      });
    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        // var d = new Date();

        // _.filter(values, function(value) {
        //   value.value = value.y;
        //   value.date = '1-' + value.x + '-' + d.getFullYear();
        // });
        return values;
      }
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

  });

})(this);