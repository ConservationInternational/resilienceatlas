(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['layers_list_tpl'],

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.collection, 'sync', this.render);
    },

    render: function() {
      var data = { categories: this.collection.getByCategory() };
      this.$el.html( this.template( data );
    }

  });

})(this);
