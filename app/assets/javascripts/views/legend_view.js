(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Legend = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['legend_tpl'],

    events: {
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
    },

    render: function() {
      var data = {};
      this.$el.html( this.template( data ) );
    },

  });

})(this);
