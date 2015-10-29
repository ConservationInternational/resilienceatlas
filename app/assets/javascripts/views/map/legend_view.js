(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Legend = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['map/legend_tpl'],
    templateLegends: {
      choropleth : HandlebarsTemplates['map/legend_choropleth_tpl'],
      custom : HandlebarsTemplates['map/legend_custom_tpl'],
      'legend-round' : HandlebarsTemplates['map/legend_round_tpl']
    },

    model: new (Backbone.Model.extend({
      defaults: {
        hidden: false,
        order: []
      }
    })),

    events: {
      'click .btn-minimize' : 'setPanelVisibility',
      'click .btn-visibility' : 'setMapVisibility',
      'click .btn-remove' : '_removeLayer'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this.setListeners();
    },

    setListeners: function() {
      _.bindAll(this,'setOrder');
      this.listenTo(this.model, 'change:hidden', this.changeVisibility);
      Backbone.Events.on('render:map', _.bind(this.render, this));
      Backbone.Events.on('legend:render', _.bind(this.render, this));
    },

    cacheVars: function() {
      this.$header = this.$el.find('.m-legend__header');
      this.$content = this.$el.find('.m-legend__content');
      this.$legendList = this.$el.find('.m-legend__list');
    },

    render: function() {
      var data = _.sortBy(this.setLegends(), 'order').reverse();

      $.when.apply($, data).done(function() {
        this.$el.html( this.template({ legends: data }) );
        this.cacheVars();
        //Set legend dragable when no journey embeded map.
        if (!this.model.get('journeyMap')) {
          this.setDraggable();
        }
      }.bind(this));
    },

    setLegends: function() {
      return _.map(this.layers.getActived(), _.bind(function(layer){
        //Check if legend exist
        if (layer.legend) {
          var legend = JSON.parse(layer.legend);
          var type = legend.type;
          layer.tpl = this.templateLegends[type](legend);
        }
        return layer;
      }, this ));
    },

    /**
     * Set draggable beahaviour (jquery-ui sortable)
     */
    setDraggable: function() {
      this.$legendList.sortable({
        axis: 'y',
        items: ".drag-items",
        tolerance: 'pointer',
        start: function(e, ui){
          ui.placeholder.height(ui.item.outerHeight());
          $('.m-legend').addClass('is-changing');
        },
        stop: this.setOrder,
      });
    },

    setOrder: function(e, ui) {
      var total = this.$legendList.children('li').length;

      _.each(this.$legendList.children('li'), _.bind(function(layer,i){
        var currentModel = this.layers.get($(layer).data('id'));
        currentModel.set('order', total - i);
      }, this ));

      this.layers.order = total;

      $('.m-legend').removeClass('is-changing');

      Backbone.Events.trigger('render:map');
    },

    /**
     * Set panel visibility
     */
    setPanelVisibility: function(e) {
      this.model.set('hidden', !this.model.get('hidden'));
    },

    changeVisibility: function() {
      this.$header.toggleClass('is-minimize',this.model.get('hidden'));
      this.$content.toggleClass('is-hidden',this.model.get('hidden'));
    },


    /**
     * Set layer visibility
     */
    setMapVisibility: function(e) {
      var $current = $(e.currentTarget).data('id');
      var currentModel = this.layers.get($current);
      var currentOpacity = currentModel.get('opacity');

      //Layer model sets
      if (currentOpacity === 0) {
        currentModel.set('opacity', 1);
        currentModel.set('no_opacity', false);
      } else {
        currentModel.set('opacity', 0);
        currentModel.set('no_opacity', true);
      }

      Backbone.Events.trigger('opacity', {'currentModel': $current, 'opacityVal': currentModel.get('opacity')});
    },

    _removeLayer: function(e) {
      e && e.preventDefault;

      var currentLayerId = $(e.currentTarget).data('layerid');

      $('.drag-items[data-id="'+ currentLayerId +'"]').remove();
      $('.panel-input-switch#layer_'+currentLayerId).prop('checked', false);

      Backbone.Events.trigger('remove:layer', currentLayerId);
    }

  });

})(this);
