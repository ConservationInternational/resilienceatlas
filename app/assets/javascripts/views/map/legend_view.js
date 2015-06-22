define([
  'backbone',
  'underscore',
  'handlebars',
  'lib/utils',
  'text!templates/map/legend_view_tpl.handlebars'
], function(Backbone, _, Handlebars, utils, TPL) {

 'use strict';

  var LegendView = Backbone.View.extend({

    events: {
      'click .legend-button': 'toggleLegend',
      'click .legend-btn-close': 'toggleLegend'
    },

    template: Handlebars.compile(TPL),

    initialize: function(options) {
      this.layers = options.layers;
      this.visible = false;

      this.render();
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.layers, {
        'change': this.render
      }, this);
    },

    render: function() {
      var self = this;
      var activeLayers = this.layers.getActiveLayers();
      _.map(activeLayers, function(layer) {
        if(!layer.groupSlug && layer.layerGroup) {
          var group = self.layers.where({slug: layer.layerGroup});
          if(group && group[0]) {
            layer.groupSlug = layer.layerGroup;
            layer.groupName = group[0].get('name') || group[0].get('group');
          }
        }
        return layer;
      });

      var group = _.groupBy(activeLayers, 'groupSlug');

      if(activeLayers.length > 0) {
        this.$el.addClass('show');
        this.$el.html(this.template({layers: group}));
      } else {
        this.$el.removeClass('show');
      }
    },

    toggleLegend: function() {
      if(!this.visible) {
        this.$el.addClass('legend-visible');
        this.visible = true;
      } else {
        this.$el.removeClass('legend-visible');
        this.visible = false;
      }
    }

  });

  return LegendView;
});
