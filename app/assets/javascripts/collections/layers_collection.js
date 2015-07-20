define([
  'underscore',
  'backbone',
  'models/layer_model'
], function(_, Backbone, LayerModel) {

  'use strict';

  var LayersCollection = Backbone.Collection.extend({

    model: LayerModel,

    parse: function(data) {
      var layers = [];

      _.each(data, function(group) {
        _.each(group.layers, function(layer) {
          layer.groupName = group.group;
          layer.groupSlug = group.slug;
          layer.groupActive = group.active;
          layer.groupOrder = group.order;
          layer.groupInfo = group.info;
          layer.category = group.category;

          _.each(layer.layers, function(sublayer) {
            sublayer.groupName = group.group;
            sublayer.layerGroup = layer.slug;
            sublayer.groupLayer = true;
            sublayer.category = layer.category;

            layers.push(sublayer);

            _.each(sublayer.layers, function(secondSublayer) {
              secondSublayer.groupName = group.group;
              secondSublayer.layerGroup = sublayer.slug;
              secondSublayer.groupLayer = true;
              secondSublayer.category = layer.category;

              layers.push(secondSublayer);
            });
          });

          layer.layers = null;
          layers.push(layer);
        });
      });

      return layers;
    },

    getByGroup: function() {
      var data = this.toJSON();
      return _.groupBy(data, 'group');
    },

    getByCategory: function() {
      var data = this.toJSON();
      return _.groupBy(data, 'category');
    },

    getByCategoryAndGroup: function() {
      var data = this.toJSON();
      var categories = _.groupBy(data, 'category');
      var groups = [];

      _.each(categories, function(c, key) {
        var layersGrouped = _.groupBy(_.where(c, {groupLayer: false}), 'groupName');
        var group = {name: key, groups: []};

        _.each(layersGrouped, function(layer, layerKey) {
          var sortedLayers = _.sortBy(layer, 'order');
          var groupType = layer[0].groupType ? sortedLayers[0].type : layer[0].type;

          group.groups.push({
            groupName: layer[0].groupName,
            groupOrder: layer[0].groupOrder,
            groupInfo: layer[0].groupInfo,
            groupSlug: layer[0].groupSlug,
            groupActive: layer[0].groupActive,
            groupLayer: groupType === 'layer' ? true : false,
            layers: _.filter(sortedLayers, function(lay) {
              var subLayers = _.where(data, {groupLayer: true, layerGroup: lay.slug});

              if(subLayers.length > 0) {
                subLayers = _.map(subLayers, function(sublayer) {
                  var secondSublayers = _.where(data, {groupLayer: true, layerGroup: sublayer.slug});
                  if(secondSublayers.length > 0) {
                    sublayer.layers = secondSublayers;
                  }
                  return sublayer;
                });
                lay.sublayers = _.sortBy(subLayers, 'order');
              }

              return lay;
            })
          });
        });

        group.groups = _.sortBy(group.groups, 'groupOrder');
        groups[key] = group;
      });

      return groups;
    },

    getById: function(id) {
      return _.findWhere(this.toJSON(), {id: id});
    },

    getActiveLayers: function() {
      var layers = [];
      var activeLayers = this.where({active: true, type: 'layer'});

      _.each(activeLayers, function(layer) {
        layers.push(layer.toJSON());
      });

      return layers;
    },

    toGeoJSON: function() {
      var data = this.toJSON();
      var geojson = {
        type: 'FeatureCollection',
        features: _.map(data, function(d) {
          var properties = _.clone(d);
          if (properties.geom) {
            delete properties.geom;
          }
          return {
            type: 'Feature',
            geometry: JSON.parse(d.geom),
            properties: properties
          };
        })
      };
      return geojson;
    }

  });

  return LayersCollection;

});
