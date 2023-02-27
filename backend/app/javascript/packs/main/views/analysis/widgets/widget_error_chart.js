(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetErrorChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-error-chart'
    },

    bucket: ['#43AB3C', '#6BC2EC', '#D8D8D8', '#0088CE', '#417505', '#00608E'],

    template: HandlebarsTemplates['analysis/widgets/widget_error_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;
      this.compare = null;

      root.app.View.WidgetBarChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      var legendData = _.union(this.compare, this.data);
      var legend = this.getLegendData(legendData);

      this.charts.buildErrorChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: this.data,
        compareData: this.compare,
        hover: true,
        loader: 'is-loading',
        interpolate: 'basis',
        unit: this.unit,
        unitZ: this.unitZ,
        hasLine: this.hasLine
      });

      this.charts.buildLegend({
        elem: '#' + this.slug + '-legend',
        contentWidth: 300,
        data: legend,
        unit: '',
        decimals: 0
      });
    },

    parseData: function(data) {
      var self = this;

      if(data) {
        var values = data.rows;

        var dataList = _.reject(values, function(d) {
          return d.category === 'Climate';
        });

        _.filter(dataList, function(value, i) {
          value.value = value.z;
          value.color = self.bucket[i+1];
        });

        var compare = _.filter(values, function(d) {
          if(d.category === 'Climate') {
            d.color = self.bucket[0];
          }
          return d.category === 'Climate';
        });

        if(compare && compare.length) {
          this.compare = compare;
        }

        return dataList;
      }
    },

    getLegendData: function(data) {
      var legendValues = [];
      var bucket = this.bucket;
      var categories = _.groupBy(data, 'label');
      var labels = _.keys(categories);

      _.each(labels, function(label, i) {
        legendValues.push({ name: label, color: bucket[i] });
      });
      return legendValues;
    },

  });

})(this);