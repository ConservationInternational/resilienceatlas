(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetBarChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-bar-chart'
    },

    template: HandlebarsTemplates['analysis/widgets/widget_bar_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;

      root.app.View.WidgetBarChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      new this.charts.buildBarsChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: this.data,
        hover: true,
        loader: 'is-loading',
        interpolate: 'basis',
        unit: this.unit,
        unitZ: this.unitZ,
        hasLine: this.hasLine,
        xAxisTickFormatter: this.options.xAxisTickFormatter
      });
    },

    parseData: function(data) {
      var self = this;
      if(data) {
        var values = data.rows;

        _.each(values, function(value) {
          value.x = value.min;
          value.y = value.count;

          value.value = value.y;
          value.color = '#0089CC';

          if(self.hasLine) {
            value.color = '#D8D8D8';
            value.lineColor = '#0089CC';
          }

          if(value.y < 0) {
            value.color = '#D8D8D8';
          }
        });
        return values;
      }
    }

  });

})(this);
