(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['layers_list_tpl'],

    events: {
      'click .m-layers-list-header': '_toggleCategories',
      'change .header-input-switch': '_toggleAllLayers',
      'change .panel-input-switch': '_toggleLayers',
      'input input.opacity-range' : '_transparencyRangeChanges',
      'change .opacity-teller': '_transparencyInputChange',
      'click .panel-trasparecy-switcher' : '_openOpacityHandlers'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this._setListeners();
    },

    _setListeners: function() {
      this.listenTo(this.layers, 'change:active', this.__toggleCategoriesSwitches);
    },

    render: function() {
      var data = { groups: this.layers.getGrouped() };
      this.$el.html( this.template( data ) );
      this._cacheVars();
      this._setActiveGroups();
    },

    _setActiveGroups: function() {
      var activeElements = this.$completeList.find('.m-layers-list-header.is-active');

      $.each(activeElements, function() {
        var parentList = $(this).parents('ul');
        var listHeader = parentList.siblings('.m-layers-list-header');

        parentList.addClass('is-active');
        listHeader.addClass('is-active');
      })
    },

    _cacheVars: function() {
      this.$headerSwitch = $('.header-switch');
      this.$completeList = $('.m-layers-list');
    },

    _toggleLayers: function() {
      var checkboxes = this.$el.find('.panel-item-switch input:checked');
      var activedIds = _.map(checkboxes, function(el) {
        return parseInt(el.id.split('layer_')[1]);
      });
      _.each(this.layers.models, function(model) {
        var active = _.contains(activedIds, model.id);
        model.set('active', active);
      });
    },

    _toggleAllLayers: function(e) {
      var $el = $(e.currentTarget);
      var $ul = $el.closest('li').find('ul:first');
      var checked = $el.prop('checked');
      $ul.find('.panel-item-switch input').prop('checked',checked);
      this._toggleLayers();
    },

    __toggleCategoriesSwitches: function() {
      var categories = this.layers.getCategories();
      _.each(categories, function(c){
        $('#categoryHeader_'+c.id).find('input').prop('checked',c.active);
      });
    },

    // Toggle categories
    _toggleCategories: function(e) {
      var $el = $(e.currentTarget);
      var $list = $el.closest('li').find('ul:first');
      $list.toggleClass('is-active');
      $el.toggleClass('is-active');
    },

    // Handles opacity from range input.
    _transparencyRangeChanges: function(e) {
      var activeControl = e.currentTarget
      var transparencyLevel = activeControl.value;

      $(activeControl).parent().siblings('.opacity-teller').val(transparencyLevel);

      this._setOpacity(transparencyLevel, activeControl);
    },

    //Handles opacity from input.
    _transparencyInputChange: function(e) {
      var $currentTarget = $(e.currentTarget)
      var opacityAmount = $currentTarget.val();
      var $currentRangeSelector = $currentTarget.siblings('.slider-wrapper').find('.opacity-range');

      $currentRangeSelector.val(opacityAmount);

      this._setOpacity(opacityAmount, $currentRangeSelector);
    },

    _setOpacity: function(val, currentSelector) {
      var activeControl = currentSelector;
      var transparencyLevel = val;

      var model = this.layers.get($(activeControl).data('id'));

      $(activeControl).siblings('.opacity').css({width: transparencyLevel + '%'});
      model.set('opacity', transparencyLevel/100);
    },

    _openOpacityHandlers: function(e) {
      $(e.currentTarget).parent().toggleClass('is-open');
    }

  });

})(this);

