(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.WidgetBarChart = root.app.View.Widget.extend({

    defaults: {

    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      root.app.View.WidgetBarChart.__super__.initialize.apply(this);
    }

  });

})(this);