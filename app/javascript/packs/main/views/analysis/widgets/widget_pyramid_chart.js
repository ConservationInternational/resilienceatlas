(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetPyramidChart = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-bar-chart'
    },

    bucket: ['#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C', '#65C1EE', '#0088CE', '#D8D8D8', '#43AB3C'],

    template: HandlebarsTemplates['analysis/widgets/widget_pyramid_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.charts =  new root.app.Helper.Charts();
      this.hasLine = this.options.hasLine || false;

      root.app.View.WidgetPyramidChart.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      this.charts.buildPyramidChart({
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
      var self = this;

      if(data) {
        var values = data.rows;
        var groups = _.groupBy(values, 'group');
        var categoriesGroups = _.groupBy(values, 'category');
        var valuesList = [];

        for(var group in groups){
          var gr = {
            group: self.labels[group],
          };

          var i = 1;
          for(var cat in categoriesGroups) {
            var list = _.findWhere(categoriesGroups[cat], {group: group, category: cat});
            gr['category'+i] = list.value;
            gr['color'+i] = self.bucket[i-1];
            gr['label'+i] = cat;
            i++;
          }

          valuesList.push(gr);
        }

        return valuesList;
      }
    }

  });

})(this);