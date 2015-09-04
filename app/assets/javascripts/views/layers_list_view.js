(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    layersOrder: 1000,

    template: HandlebarsTemplates['layers_list_tpl'],

    events: {
      'click .m-layers-list-header': '_toggleCategories',
      'change .header-input-switch': '_toggleAllLayers',
      'change .panel-input-switch': '_setLayersOrder',
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
      this.listenTo(this.layers, 'change:active', this._toggleCategoriesSwitches);
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

    _setLayersOrder: function(e) {
      this._toggleLayers();

      var $currentTarget = $(e.currentTarget);
      var id = parseInt($currentTarget.attr('id').split('layer_')[1]);

      if ($currentTarget.prop('checked')) {
        var currentModel = _.findWhere(this.layers.models, {'id': id});
        currentModel.set('order', this.layersOrder);
        console.log(this.layersOrder)
        console.log(currentModel);
        return this.layersOrder --;
      }
    },

    _toggleAllLayers: function(e) {
      var $el = $(e.currentTarget);
      var $ul = $el.closest('li').find('ul:first');
      var checked = $el.prop('checked');
      $ul.find('.panel-item-switch input').prop('checked',checked);
      this._toggleLayers();
    },

    _toggleCategoriesSwitches: function() {
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
      var opacity = activeControl.value;

      $(activeControl).parent().siblings('.opacity-teller').val(opacity);

      this._setOpacity(opacity, activeControl);
    },

    //Handles opacity from input.
    _transparencyInputChange: function(e) {
      var $currentTarget = $(e.currentTarget)
      var opacity = $currentTarget.val();
      var $currentRangeSelector = $currentTarget.siblings('.slider-wrapper').find('.opacity-range');

      $currentRangeSelector.val(opacity);

      this._setOpacity(opacity, $currentRangeSelector);
    },

    _setOpacity: function(opacity, currentSelector) {

      var model = this.layers.get($(currentSelector).data('id'));

      $(currentSelector).siblings('.opacity').css({width: opacity + '%'});
      model.set('opacity', opacity/100);

      this._manageOpacityIcon(opacity, currentSelector);
    },

    _manageOpacityIcon: function(opacity, currentSelector) {
      var $currentWrapper = $(currentSelector.closest('li'));

      if (opacity != 100) {
        $currentWrapper.addClass('is-modified');
      } else {
        $currentWrapper.removeClass('is-modified');
      }
    },

    _openOpacityHandlers: function(e) {
      $(e.currentTarget).parent().toggleClass('is-open');
    }

  });

})(this);

