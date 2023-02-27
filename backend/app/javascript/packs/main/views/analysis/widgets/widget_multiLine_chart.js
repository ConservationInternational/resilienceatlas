(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetMultiLineChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-line-chart'
    },

    bucket: ['#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C', '#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_line_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      
      root.app.View.WidgetMultiLineChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      var legend = this.getLegendData();
      this.charts.buildMultiLineChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 30,
        barSeparation: 45,
        data: this.data,
        hover: true,
        decimals: 0,
        dataKeys: 4,
        loader: 'is-loading',
        interpolate: 'cardinal',
        dateFormat: '%b',
        unit: this.unit,
        bucket: this.bucket,
        margin: {
          top: 30,
          right: 40,
          bottom: 40,
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
        decimals: 0
      });
    },

    parseData: function(data) {

      if(data) {
        //If multiple lines, split each data objet into multiple objects.
        var symbols = Object.keys(data.rows[0]);
        var index = symbols.indexOf('x');
        symbols.splice(index, 1);

        var values = [];

        $.each(symbols, function() {
          var currentSymbol = this;

          var valuesByCategory = _.pluck(data.rows, currentSymbol);
          var dates = _.pluck(data.rows, 'x');

          $.each(valuesByCategory, function(i) {
            var dataSet = {};
              
            dataSet.symbol = currentSymbol;
            dataSet.value = this;
  
            dataSet.year = 'Jan '+dates[i];
            values.push(dataSet);
          });
        });
        return values;
      }
    },

    getLegendData: function() {
      var legendValues = [];
      var bucket = this.bucket;
      var categories = this.options.labels;
      var labels = _.values(categories);

      _.each(labels, function(label, i) {
        legendValues.push({ name: label, color: bucket[i] });
      });
      return legendValues;
    },

  });

})(this);