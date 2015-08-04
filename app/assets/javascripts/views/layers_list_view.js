(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['layers_list_tpl'],

    events: {
      'change input': 'updateLayers'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
    },

    render: function() {
      // var currentGroup = 1;
      var data = { groups: this.layers.getGrouped() };
      console.log(data);
      // var group = _.findWhere(data, { id: currentGroup });
      // var data = { categories: group ? group.categories : [] };
      this.$el.html( this.template( data ) );
    },

    updateLayers: function() {
      var checkboxes = this.$el.find('.panel-item-switch input:checked');
      var activedIds = _.map(checkboxes, function(el) {
        return parseInt(el.id.split('layer_')[1]);
      });
      _.each(this.layers.models, function(model) {
        var active = _.contains(activedIds, model.id);
        model.set('active', active);
      });
    },

  });

})(this);
