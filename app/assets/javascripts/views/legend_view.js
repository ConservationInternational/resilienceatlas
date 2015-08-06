(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Legend = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['legend_tpl'],
    templateLegends: {
      choropleth : HandlebarsTemplates['legend_choropleth_tpl']
    },

    model: new (Backbone.Model.extend({
      defaults: {
        hidden: false,
      }
    })),

    events: {
      'click .btn-minimize' : 'setVisibility',
      'click .btn-visibility' : 'setMapVisibility',
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.model, 'change:hidden', this.changeVisibility);
      this.listenTo(this.layers, 'change', this.render);
    },

    cacheVars: function() {
      this.$header = this.$el.find('.m-legend__header');
      this.$content = this.$el.find('.m-legend__content');
      this.$legendList = this.$el.find('.m-legend__list');
    },

    render: function() {
      var data = this.setLegends();
      this.$el.html( this.template({ legends: data}) );

      this.cacheVars();
      this.setDraggable();
    },

    setLegends: function() {
      return _.map(this.layers.getActived(), _.bind(function(layer){
        var legend = JSON.parse(layer.legend);
        var type = legend.type;

        layer.tpl = this.templateLegends[type](legend);

        return layer;
      }, this ));
    },

    setDraggable: function() {
      this.$legendList.sortable({
        axis: 'y',
        items: ".drag-items",
        start: function(e, ui){
          ui.placeholder.height(ui.item.outerHeight());
        },
      });
    },

    setVisibility: function(e) {
      this.model.set('hidden', !this.model.get('hidden'));
    },

    changeVisibility: function() {
      this.$header.toggleClass('is-minimize',this.model.get('hidden'));
      this.$content.toggleClass('is-hidden',this.model.get('hidden'));
    },

    setMapVisibility: function(e) {
      var $current = $(e.currentTarget);
      var currentModel = this.layers.get($current.data('id'));
      // Layer model sets
      if ($current.hasClass('is-active')) {
        currentModel.set('opacity', currentModel.get('opacity_prev'));
        currentModel.set('opacity_prev', null);
      } else {
        currentModel.set('opacity_prev', currentModel.get('opacity'));
        currentModel.set('opacity', 0);
      }
    },

  });

})(this);
