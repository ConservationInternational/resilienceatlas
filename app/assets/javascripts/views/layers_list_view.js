(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['layers_list_tpl'],

    events: {
      'click .m-layers-list-header': 'toggleCategories',
      'change .header-input-switch': 'toggleAllLayers',
      'change .panel-input-switch': 'toggleLayers',
      'input input.opacity-range' : 'updateTransparency',
      'click .panel-trasparecy-switcher' : 'openOpacityHandler'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.layers, 'change:active', this.toggleCategoriesSwitches);
    },

    render: function() {
      var data = { groups: this.layers.getGrouped() };
      this.$el.html( this.template( data ) );
      this.cacheVars();
    },

    cacheVars: function() {
      this.$headerSwitch = $('.header-switch');
    },

    toggleLayers: function() {
      var checkboxes = this.$el.find('.panel-item-switch input:checked');
      var activedIds = _.map(checkboxes, function(el) {
        return parseInt(el.id.split('layer_')[1]);
      });
      _.each(this.layers.models, function(model) {
        var active = _.contains(activedIds, model.id);
        model.set('active', active);
      });
    },

    toggleAllLayers: function(e) {
      var $el = $(e.currentTarget);
      var $ul = $el.closest('li').find('ul:first');
      var checked = $el.prop('checked');
      $ul.find('.panel-item-switch input').prop('checked',checked);
      this.toggleLayers();
    },

    toggleCategoriesSwitches: function() {
      var categories = this.layers.getCategories();
      _.each(categories, function(c){
        $('#categoryHeader_'+c.id).find('input').prop('checked',c.active);
      });
    },

    // Toggle categories
    toggleCategories: function(e) {
      var $el = $(e.currentTarget);
      var $list = $el.closest('li').find('ul:first');
      $list.toggleClass('is-active');
      $el.toggleClass('is-active');
    },

    updateTransparency: function(e) {
      var activeControl = e.currentTarget
      var transparencyLevel = activeControl.value;

      $(activeControl).parent().siblings('.opacity-teller').html(transparencyLevel + '%');
      $(activeControl).siblings('.opacity').css({width: transparencyLevel + '%'});
    },

    openOpacityHandler: function(e) {
      $(e.currentTarget).parent().toggleClass('is-open');
    }

  });

})(this);

