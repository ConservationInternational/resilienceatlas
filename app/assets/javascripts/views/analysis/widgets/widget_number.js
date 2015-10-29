(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetNumber = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-number',
      widgetName: 'number'
    },

    template: HandlebarsTemplates['analysis/widgets/widget_number_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      root.app.View.WidgetNumber.__super__.initialize.apply(this);
    },

    renderWidget: function() {

    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        var valuesList = [];

        _.each(values, function(value) {
          valuesList.push({
            value: value.value,
            unit: value.unit || ''
          })
        });

        return values;
      }
    }

  });

})(this);