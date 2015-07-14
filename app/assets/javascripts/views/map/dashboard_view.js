define([
  'underscore',
  'backbone',
  'handlebars',
  'foundation',
  'uri/URI',
  'views/helpers/modal_window_view',
  'text!templates/map/dashboard_tpl.handlebars'
], function(_, Backbone, Handlebars, foundation, URI, ModalWindowView, TPL) {

  'use strict';

  var DashboardView = Backbone.View.extend({

    defaults: {},

    events: {
      'change .layer-switch': 'update',
      'change .basemap-switch': 'updateBasemap',
      'change .sublayer-switch': 'updateSublayer',
      'click .btn-info': 'openLayerInfo',
      'click .locate-layer': 'locateLayer',
      'click .tabs a': 'toggleTabs'
    },

    template: Handlebars.compile(TPL),

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);
      this.layers = this.options.layers;
      this.topics = this.options.topics;
      this.regions = this.options.regions;
      this.params = this.options.params;
      this.map = this.options.map;

      //this.render();
    },

    toggleTabs: function(ev) {
      ev.preventDefault();

      var $tab = $(ev.currentTarget);
      var $tabs = this.$('.tabs > li');
      var $body = $('body');

      if(!$body.hasClass('dashboard-opened')) {
        $body.addClass('dashboard-opened');
      }

      if($tab.hasClass('opened')){
        $body.removeClass('dashboard-opened');
        $tab.removeClass('opened');
      } else {
        $tabs.removeClass('opened');
        $tab.addClass('opened');
      }

      this.renderSelectedLayers();
    },

    render: function() {
      this.$el.html(this.template(this.data));
      this.afterRender();
      this.renderLayerComponents();
      this.renderSelectedLayers();

      this.addActiveState();
    },

    renderSelectedLayers: function() {
      var $layer = this.$('.tab-layer .ic-active-layers');
      var $basemap = this.$('.tab-basemap .ic-active-layers');
      // var $context = this.$('.tab-context .ic-active-layers');

      var numLayers = this.layers.where({category: 'layer', active: true});
      var numBasemaps = this.layers.where({category: 'basemap', active: true});
      // var numContext = this.layers.where({category: 'context', active: true});

      $layer.html(numLayers.length || '');
      $basemap.html(numBasemaps.length || '');
      // $context.html(numContext.length || '');
    },

    afterRender: function() {
      $(document).foundation();
      this.$el.addClass('visible');
    },

    formatLayers: function(layers) {
      var self = this;
      var formattedData = _.map(layers.groups, function(layerGroup) {
        _.each(layerGroup.layers, function(layer) {
          layer.activeCheck = layer.active ? 'checked' : '';
        });

        var layerGroupNum = layerGroup.groupSlug ? layerGroup.groupSlug.length : 0;

        if(layerGroupNum > 0) {
          return {
            name: layerGroup.groupName,
            active: layerGroup.groupActive ? 'active': '',
            info: layerGroup.groupInfo || false,
            locateLayer: layerGroup.locateLayer || false,
            groupLayer: layerGroup.groupLayer,
            slug: layerGroup.groupSlug,
            layers: _.map(layerGroup.layers, function(layer) {
              layer.activeColor = (layer.color && layer.active) ? layer.color : '';
              layer.name = layer.name || layer.group;

              if(layer.sublayers) {
                layer.color = layer.color;
                layer.sublayers = self.formatSubgroups(layer);
              }
              return layer;
            })
          };
        } else {
          layerGroup.layers[0].noGroup = true;
          layerGroup.layers[0].info = layerGroup.groupInfo || false;
          return layerGroup.layers[0];
        }
      });

      return formattedData;
    },

    formatSubgroups: function(layer) {
      return _.map(layer.sublayers, function(sublayer) {
        sublayer.activeColor = (sublayer.color && sublayer.active) ? sublayer.color : '';
        sublayer.activeCheck = sublayer.active ? 'checked' : '';
        sublayer.locateLayer = sublayer.locateLayer;

        if(sublayer.active) {
          layer.activeColor = layer.color;
        }

        if(sublayer.activeCheck) {
          layer.activeCheck = 'checked';
        }

        if(sublayer.layers) {
          sublayer.layers = _.map(sublayer.layers, function(secondSubLayer) {
            secondSubLayer.activeColor = (secondSubLayer.color &&
              secondSubLayer.active) ? sublayer.color : '';
            secondSubLayer.activeCheck = secondSubLayer.active ? 'checked' : '';
            return secondSubLayer;
          });
        }

        return sublayer;
      });
    },

    setUrlParams: function(params) {

      if (params && params.hasOwnProperty('tab')) {

        this.desactivateLayers();

        switch(params.tab) {
          case 'layers':
            console.info('getting layers...');
            this.getLayers(params);
            this.setActiveLayers(params);
            break;
          case 'topics':
            console.info('getting topics...');
            if (params.id) {
              this.getTopic(params.id);
              this.setActiveLayers(params);
            } else {
              this.getTopicList();
            }
            break;
          case 'regions':
            console.info('getting regions...');
            this.getRegions();
            break;
        }

        //this.render();
      };
    },

    getLayers: function(params) {
      var self = this;
      var layersParams = _.flatten(_.values(params));
      var layersCollection = _.clone(this.layers);

      _.each(layersParams, function(currentLayer) {
        var layer = {slug: currentLayer};
        var layerModel = layersCollection.findWhere(layer);

        if(layerModel) {
          var category = layerModel.get('category');

          if(category === 'basemap') {
            _.map(layersCollection.models, function(model){
              if(model.get('category') === 'basemap') {
                model.set({active: false});
              }
            });
          }

          layerModel.set({active: true});
        }
      });

      var dataByCategories = this.layers.getByCategoryAndGroup();
      var layers = this.formatLayers(dataByCategories.layer);
      var basemaps = this.formatLayers(dataByCategories.basemap);
      // var context = this.formatLayers(dataByCategories.context);

      this.data = {
        layers: layers,
        basemaps: basemaps,
        // context: context
      };

      this.render();
      //this.layers.reset(layersCollection.models);
    },

    setActiveLayers: function(params) {

      if (params && params.hasOwnProperty('active')) {
        var layersCollection = _.clone(this.layers);
        var layersByUrl = params.active.split(','),
          layers = layersCollection.toJSON();

        layersByUrl.forEach(_.bind(function(l) {
          _.each(layers, _.bind(function(layer) {
            if (layer.type === 'layer' && layer.slug === l) {
              this.addActiveState.apply($('#dashboard-layers-item-' + layer.groupSlug));
              $('#dashboard-layers-item-' + layer.groupSlug).find('#' + layer.slug).prop('checked', 'checked');
              this.update(false, $('#dashboard-layers-item-' + layer.groupSlug).find('#' + layer.slug));
            }
          }, this));
        }, this));
      }
    },

    getTopic: function(id) {
      var topicInfo = this.topics.getTopic(id);
      var layers = _.clone(this.layers);
      var layersByTopic = [];

      var layersByTopicId = _.map(topicInfo.layers, function(layer) {
        return layer.id;
      });

      _.each(layersByTopicId, function(id) {
        layersByTopic.push(layers.getById(id));
      })

      layersByTopic = _.groupBy(layersByTopic, 'groupSlug');

      this.data = {
        topics: true,
        topicId: true,
        data: topicInfo,
        layersByTopic: layersByTopic
      };

      this.render();
    },

    getTopicList: function() {
      var topics = this.topics.getTopicsList();

      this.data = {
        topics: true,
        data: topics
      };

      this.render();
    },

    getRegions: function(params) {

      this.regions.getByRegions(_.bind(function() {

        this.data = {
          regions: true,
          data: this.regions.toJSON()
        };

        this.render();

      }, this));
    },

    desactivateLayers: function() {
      var layers = this.layers.toJSON();

      layers.forEach(function(layer) {
        if (layer.type === 'layer' && layer.active === true) {
          layer.active = false;
        }
      });


      this.layers.reset(layers);
      this.layers.trigger('change');
    },

    update: function(ev, element) {
      var currentEl = ev ? ev.currentTarget : element;
      var $el = $(currentEl);
      var $parent = $el.parent('.switcher');
      var $switchEl = $parent.find('label');
      var slug = $el.data('layer-slug');
      var layers = _.clone(this.layers);

      var layer = {slug: slug};

      var layerValue = $el.prop('checked');
      var layerModel = layers.findWhere(layer);

      layerModel.set({active: layerValue});
      this.layers.reset(layers.models);

      if(layerValue) {
        var color = layerModel.get('color') || '';
        $switchEl.css({
          'backgroundColor': color,
          'borderColor': color
        });
      } else {
        $switchEl.attr('style', '');
      }

      Backbone.Events.trigger('dashboard:change', {
        layerValue: layerValue,
        slug: slug
      });

      this.renderLayerComponents(layers.models);
    },

    updateSublayer: function(ev) {
      var self = this;
      var checked = 0;
      var $el = $(ev.currentTarget);
      var $parent = $el.parents('.content');
      var slug = $el.data('parent-slug') || $el.data('layer-slug');

      var $sublayers = $parent
        .find("[data-parent-slug='" + slug + "']");
      var $parentSwitch = $parent
        .find("[data-layer-slug='" + slug + "']");
      var $parentLabel = $parent
        .find("[for='" + slug + "']");

      if(!$el.hasClass('parent')) {
        this.update(ev);

        $sublayers.find('.layer-item').each(function(){
          var $item = $(this);
          var $input = $item.find('.sublayer-switch.main');

          if($input.prop('checked')) {
            checked++;
          }
        });

        if(checked > 0) {
          var color = $parentSwitch.data('layer-color');
          $parentSwitch.prop('checked', true);
          $parentLabel.css({
            'backgroundColor': color,
            'borderColor': color
          });
        } else {
          $parentSwitch.prop('checked', false);
          $parentLabel.attr('style', '');
        }
      } else {
        var unMarkedAll = true;
        var color = $el.data('layer-color');

        if($el.prop('checked')) {
          unMarkedAll = false;
          $parentLabel.css({
            'backgroundColor': color,
            'borderColor': color
          });
        } else {
          $parentLabel.attr('style', '');
        }

        $sublayers.find('.layer-item').each(function(){
          var $item = $(this);
          var $input = $item.find('.sublayer-switch.main');

          if($input.length >= 1) {
            if(unMarkedAll) {
              $input.prop('checked', false);
            } else {
              $input.prop('checked', true);
            }
            self.update(false, $input);
          }
        });
      }
    },

    updateBasemap: function(ev) {
      var $el = $(ev.currentTarget);
      var slug = $el.data('layer-slug');
      var layers = _.clone(this.layers);

      var dataByCategories = layers.getByCategoryAndGroup();
      var basemaps = dataByCategories.basemap.groups[0];

      _.each(basemaps.layers, function(basemap) {
        var layer = {slug: basemap.slug};
        var layerModel = layers.findWhere(layer);
        var active = false;

        if(basemap.slug === slug) {
          active = true;
        }

        layerModel.set({active: active});
      });

      this.layers.reset(layers.models);
    },

    openLayerInfo: function(ev) {
      ev.preventDefault();
      ev.stopPropagation();

      var layers = _.clone(this.layers);

      var $el = $(ev.currentTarget);
      // var $modalBox = $('#modalBox');
      var infoLayer,
        data,
        slug;

      if($el.data('category')) {
        slug = $el.data('category');
        infoLayer = _.findWhere(layers.toJSON(), {groupSlug: slug});
        data = infoLayer.groupInfo;
      } else {
        slug = $el.data('slug');
        infoLayer = _.findWhere(layers.toJSON(), {slug: slug});
        data = infoLayer.info;
      }

      // $modalBox.find('.modal-content').html(info);
      // $modalBox.foundation('reveal', 'open');
      new ModalWindowView ({
        'data': data
      });
    },

    renderLayerComponents: function(layers) {
      var self = this;
      var layersModels;

      if(!layers) {
        layersModels = _.clone(this.layers.models);
      } else {
        layersModels = layers;
      }

      _.each(layersModels, function(currentLayer) {

        // Timeline
        self.renderComponentTimeline(currentLayer);

        // Locate layer
        self.renderComponentLocateLayer(currentLayer);

      });
    },

    renderComponentTimeline: function(currentLayer) {
      if(currentLayer.get('timeline')) {
        var slug = currentLayer.get('slug');
        var $timeline = $('.timeline-'+slug);

        if(currentLayer.get('active')) {
          if(!$timeline.hasClass('visible')) {
            $timeline.addClass('visible loading');
            Backbone.Events.trigger('timeline:show', slug, $timeline);
          }
        } else if(currentLayer.previous('active')) {
         $timeline.removeClass('visible');
         Backbone.Events.trigger('timeline:hide', slug);
        }
      }
    },

    renderComponentLocateLayer: function(currentLayer) {
      if(currentLayer.get('locateLayer')) {
        var slug = currentLayer.get('slug');
        var $element = this.$el.find(".layer-item[data-layer-slug='" + slug + "']");
        var $locateEl = $element.find('.locate-layer');

        if(currentLayer.get('active')) {
          $locateEl.addClass('visible');
        } else if(currentLayer.previous('active')) {
          $locateEl.removeClass('visible');
        }
      }
    },

    locateLayer: function(ev) {
      var $el = $(ev.currentTarget);
      var slug = $el.parent().data('layer-slug');
      var mapModel = this.map.model;
      var layer = mapModel.get(slug);

      if(layer) {
        layer.panToLayer();
      }
    },

    addActiveState: function() {
      // var activeEl = $('.m-dashboard').find('#dashboard-layers-item-food_security');
      $(this).parents('.accordion-navigation').addClass('active');
      $(this).addClass('active');
    }

  });

  return DashboardView;

});
