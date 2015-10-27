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
      this.charts.buildBarsChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: this.data,
        hover: true,
        loader: 'is-loading',
        interpolate: 'basis',
        hasLine: this.hasLine
      });
    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        var d = new Date();

        _.filter(values, function(value) {
          value.value = value.y;
          value.color = '#0089CC';
        });
        return values;
      }
    }

  });

})(this);