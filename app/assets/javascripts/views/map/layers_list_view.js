(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.LayersList = Backbone.View.extend({

    defaults: {},

    template: HandlebarsTemplates['map/layers_list_tpl'],

    events: {
      'click .m-layers-list-header': '_toggleCategories',
      'change .header-input-switch': '_toggleAllLayers',
      'change .panel-input-switch': '_toggleLayers',
      'input input.opacity-range' : '_transparencyRangeChanges',
      'change .opacity-teller': '_transparencyInputChange',
      'click .panel-trasparecy-switcher' : '_openOpacityHandlers',
      'click .btn-info' : '_showInfo',
      'click .btn-basemap-handler' : '_selectBasemap',
      'click .btn-download': '_downloadClicked'
      'click .btn-locate': '_setLayerBounds'

    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this._setListeners();

      this.infowindow = new root.app.View.InfoWindow;
    },

    _setListeners: function() {
      this.listenTo(this.layers, 'change:active', this._toggleCategoriesSwitches);
      Backbone.Events.on('opacity', this._transparencyChangeFromModel);
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

      this.$basemapHandlers = $('.btn-basemap-handler');
    },

    _toggleLayers: function(e) {
      var checkboxes = this.$el.find('.panel-item-switch input:checked');
      var activedIds = _.map(checkboxes, function(el) {
        return parseInt(el.id.split('layer_')[1]);
      });


      _.each(this.layers.models, function(model) {
        var active = _.contains(activedIds, model.id);
        model.set('active', active);
      });

      Backbone.Events.trigger('render:map');

      var currCheckbox = e.currentTarget;
      if (currCheckbox.checked) {
        ga('send', 'event', 'Map', 'Toggle', currCheckbox.dataset.name);
      }
    },

    /*
      Manage layer form dashboard.
     */
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

    /*
      Manage transparency layers range from dhasboard
     */
    // Handles opacity from range input.
    _transparencyRangeChanges: function(e) {
      var activeControl = e.currentTarget
      var opacity = activeControl.value;

      $(activeControl).parent().siblings('.opacity-teller').val(opacity);

      this._setOpacity(opacity, activeControl);

      ga('send', 'event','Map','Transparency', 'Slide');
    },

    //Handles opacity from text input.
    _transparencyInputChange: function(e) {
      var $currentTarget = $(e.currentTarget)
      var currentVal = parseInt($currentTarget.val());
      var opacity;

      currentVal = _.isNaN(currentVal) ? 100 : currentVal;

      if (currentVal > 100) {
        opacity = 100;
        $currentTarget.val(opacity);
      } else if (currentVal < 0) {
        opacity = 0;
        $currentTarget.val(opacity);
      } else {
        opacity = currentVal;
        $currentTarget.val(opacity);
      }

      var $currentRangeSelector = $currentTarget.siblings('.slider-wrapper').find('.opacity-range');

      $currentRangeSelector.val(opacity);

      this._setOpacity(opacity, $currentRangeSelector);
    },

    _transparencyChangeFromModel: function(values) {
     var $current = $('.m-layers-list').find('input[layer='+ values.currentModel +']')
     $current.val(values.opacityVal * 100);
     $current.trigger('change');
    },

    _setOpacity: function(opacity, currentSelector) {
      var model = this.layers.get($(currentSelector).data('id'));

      $(currentSelector).siblings('.opacity').css({width: opacity + '%'});
      model.set('opacity', opacity/100);

      this._manageOpacityIcon(opacity, currentSelector);

      if (opacity == 0) {
        model.set('no_opacity', true);
      } else {
        model.set('no_opacity', false);
      }

      Backbone.Events.trigger('render:map');
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
    },

    _showInfo: function(e) {
      e.preventDefault();
      var data = $(e.currentTarget).data('info');
      var name = $(e.currentTarget).data('name');

      this.infowindow.render(data, name);

      ga('send', 'event', 'Map', 'More information');
    },

    _selectBasemap: function(e) {
      e.preventDefault;
      this.$basemapHandlers.removeClass('is-active');
      var $target = $(e.currentTarget)
      var basemapType = $target.data('basemap');
      $target.addClass('is-active');

      Backbone.Events.trigger('basemap:change', basemapType);
    },

    _downloadClicked: function(e) {

      var layerName = e.currentTarget.dataset.name;
      if(typeof(layerName) !== 'undefined') {
        ga('send', 'event', 'Map', 'Download', layerName);
      }

    _setLayerBounds: function(e) {
      var $target = $(e.currentTarget);
      var id = $target.data('id');

      Backbone.Events.trigger('map:set:bounds', id);

    }

  });

})(this);

