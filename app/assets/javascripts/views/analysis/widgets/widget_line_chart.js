(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetLineChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-line-chart'
    },

    template: HandlebarsTemplates['analysis/widgets/widget_line_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      
      root.app.View.WidgetLineChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      this.charts.buildLineChart({
        elem: '#' + this.slug,
        barWidth: 30,
        barSeparation: 45,
        data: this.data,
        hover: true,
        decimals: 0,
        loader: 'is-loading',
        interpolate: 'cardinal'
      });
    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        var d = new Date();

        _.filter(values, function(value) {
          value.value = value.y;
          value.date = '1-' + value.x + '-' + d.getFullYear();
        });
        return values;
      }
    }

  });

})(this);