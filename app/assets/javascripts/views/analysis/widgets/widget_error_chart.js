(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetErrorChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-error-chart'
    },

    bucket: ['#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C', '#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_error_chart_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;

      root.app.View.WidgetBarChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      new this.charts.buildErrorChart({
        elem: '#' + this.slug + '-graph',
        barWidth: 22,
        barSeparation: 13,
        data: this.data,
        hover: true,
        loader: 'is-loading',
        interpolate: 'basis',
        unit: this.unit,
        unitZ: this.unitZ,
        hasLine: this.hasLine
      });
    },

    parseData: function(data) {
      var self = this;
      if(data) {
        var values = data.rows;
        var d = new Date();

        _.filter(values, function(value, i) {
          value.value = value.y;
          value.color = self.bucket[i];
          value.e = _.clone(value.y);
          value.y = value.z;
        });

        return values;
      }
    }

  });

})(this);