(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetTextList = root.app.View.Widget.extend({

    defaults: {
      charEl: '.widget-text-list'
    },

    template: HandlebarsTemplates['analysis/widgets/widget_text_list_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      root.app.View.WidgetTextList.__super__.initialize.apply(this);
    },

    renderWidget: function() {
      
    },

    parseData: function(data) {
      if(data) {
        var values = data.rows;
        return values;
      }
    }

  });

})(this);