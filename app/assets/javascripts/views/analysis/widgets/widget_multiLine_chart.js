(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetMultiLineChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-line-chart'
    },

    template: HandlebarsTemplates['analysis/widgets/widget_line_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      
      root.app.View.WidgetMultiLineChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      this.charts.buildMultiLineChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 30,
        barSeparation: 45,
        data: this.data,
        hover: true,
        decimals: 0,
        loader: 'is-loading',
        interpolate: 'cardinal',
        dateFormat: '%b',
        unit: this.unit,
        margin: {
          top: 30,
          right: 40,
          bottom: 40,
          left: 55,
          xaxis: 10,
          tooltip: 2.2
        }
      });
    },

    parseData: function(data) {

      if(data) {
        //If multiple lines, split each data objet into multiple objects.
        var symbols = Object.keys(data.rows[0]);
        var index = symbols.indexOf('x');
        symbols.splice(index, 1);

        var values = [];
        var dataSet = {};

        $.each(symbols, function() {
          var currentSymbol = this;

          var valuesByCategory = _.pluck(data.rows, currentSymbol);
          var dates = _.pluck(data.rows, 'x');

          $.each(valuesByCategory, function(i) {
            dataSet.symbol = currentSymbol;
            dataSet.value = this;
            dataSet.date = dates[i];
            values.push(dataSet);
          });
        });
        // console.log(values);
        return values;
      }
    }

  });

})(this);