(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Map = Backbone.View.extend({

    defaults: {
      defaultBasemap: 'defaultmap',
      basemap: {
        defaultmap: {
          url: 'https://api.tiles.mapbox.com/v4/cigrp.2ad62493/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g',
          labelsUrl: 'https://api.tiles.mapbox.com/v4/cigrp.829fd2d8/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g'
        },
        satellite: {
          url: 'https://api.tiles.mapbox.com/v4/cigrp.1bf29c61/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g',
          labelsUrl: 'https://api.tiles.mapbox.com/v4/cigrp.829fd2d8/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g'
        },
        topographic: {
          url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Physical_Map/MapServer/tile/{z}/{y}/{x}',
          labelsUrl: 'https://api.tiles.mapbox.com/v4/cigrp.829fd2d8/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g'
        },
        dark: {
          url: 'https://api.tiles.mapbox.com/v4/cigrp.d5f72271/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g',
          labelsUrl: 'https://api.tiles.mapbox.com/v4/cigrp.b5d2182b/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g'
        }
      },
      zoomControl: {
        position: 'topright'
      }
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.subdomainParams = settings.subdomainParams;
      this.router = settings.router;
      this.layers = settings.layers;
      this.selectedBasemap = settings.basemap;
      this.setListeners();
      this.journeyMap = this.model.get('journeyMap');
      this.currentCountry = this.model.get('countryIso') || null;
      this.zoomEndEvent = this.model.get('zoomEndEvent') || true;

      this.utils = new root.app.View.Utils();
      this.advise = new root.app.View.Advise();
    },

    setListeners: function() {
      Backbone.Events.on('render:map', _.bind(this.renderLayers, this));
      Backbone.Events.on('basemap:change', _.bind(this.selectBasemap, this));
      Backbone.Events.on('map:set:fitbounds', this.setBbox.bind(this));
      Backbone.Events.on('map:set:bounds', this._setLayerBounds.bind(this));
      Backbone.Events.on('map:set:mask', this.setMaskLayer.bind(this));
      Backbone.Events.on('map:toggle:layers', this.toggleLayers.bind(this));
      Backbone.Events.on('remove:layer', this._removingLayer.bind(this));
      Backbone.Events.on('map:redraw', this.redrawMap.bind(this));
      Backbone.Events.on('map:recenter', this.reCenter.bind(this));
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
      var self = this;
      // trampita zoom
      if (this.journeyMap && this.currentCountry==='ETH') {
        if ( $(document).width() < 1020) {
          this.options.map.zoom = 5;
          this.options.map.center = [8, 35]; //Horn of Africa
        } else {
          this.options.map.zoom = 6;
          this.options.map.center = [9, 37]; //Horn of Africa
        }
      } else if (this.journeyMap && this.currentCountry==='NER') {
        if ( $(document).width() < 1020) {
          this.options.map.zoom = 5;
          this.options.map.center = [15, 3]; //Horn of Africa
        } else {
          this.options.map.zoom = 6;
          this.options.map.center = [17, 5]; //Horn of Africa
        }
      }

      if (!this.map) {
        //This is to separate attributions with a pipe instead of comma.
        var A = L.Control.Attribution;
        A.prototype._update = function() {
          if (this._map) {
            var a = [];
            for (var b in this._attributions)
                this._attributions[b] && a.push(b);
            var c = [];
            this.options.prefix && c.push(this.options.prefix),
            a.length && c.push(a.join(" | ")),
            this._container.innerHTML = c.join(" | ")
          }
        },

        this.options.map.attributions = new A();

        this.map = L.map(this.el, this.options.map);
        this.map.on('click', function(){
          self.checkMask();
        });
        if (this.options.zoomControl) {
          this.addControlZoom();
        }
        this.setBasemap();
        this._setAttributionControl();
      } else {
        console.info('Map already exists.');
      }

      var self = this;

      this.actualZoom = this.options.map.zoom;

      this.map.on('zoomend', _.bind(function() {
        if(this.zoomEndEvent) {
          this.actualZoom = this.map.getZoom();
          this.router.setParams('zoom', this.actualZoom);
          this.finishedZooming = true;
          this.renderLayers();
        }
      }, this));

      this.map.on('dragend', _.bind(function() {
        this.actualCenter = this.map.getCenter();
        this.router.setParams('center', this.actualCenter);
      }, this));
    },

    redrawMap: function() {
      this.setBbox(this.bbox);
    },

    reCenter: function() {
      this.map.setView(this.options.map.center, this.options.map.zoom);
    },

    /**
     * Destroys the map and clears all related event listeners
     */
    removeMap: function() {
      if (this.map) {
        this.map.remove();
        this.map = null;
      } else {
        console.info('Map doesn\'t exist yet.');
      }
    },

    addControlZoom: function() {
      this.controlZoom = L.control.zoom(this.options.zoomControl);
      this.map.addControl(this.controlZoom);
    },

    selectBasemap: function(basemapType) {
      this.selectedBasemap = basemapType;
      var newBasemapUrl = this.options.basemap[basemapType].url;
      this.setBasemap(newBasemapUrl, basemapType);
    },

    _getBaseMapUrl: function() {
      return this.selectedBasemap ? this.options.basemap[this.selectedBasemap].url : this.options.basemap.defaultmap.url;
    },

    _getBaseMapLabelsUrl: function() {
      return this.selectedBasemap ? this.options.basemap[this.selectedBasemap].labelsUrl : this.options.basemap.defaultmap.labelsUrl
    },


    /**
     * Add a basemap to map
     * @param {String} basemapUrl https://{s}.tile.osm.org/{z}/{x}/{y}.png
     */
    setBasemap: function(basemapUrl, type) {
      if (!this.map) {
        throw 'Map must exists.';
      }
      if (this.basemap) {
        this.map.removeLayer(this.basemap);
        this.map.removeLayer(this.labels);
      }

      var labelsUrl = this._getBaseMapLabelsUrl();
      var url = basemapUrl || this._getBaseMapUrl();
      var basemap = type || this.selectedBasemap || this.options.defaultBasemap;

      if (this.journeyMap) {
        this.basemap = L.tileLayer(url).addTo(this.map);
      } else {
        this.basemap = L.tileLayer(url).addTo(this.map);
        this.labels = L.tileLayer(labelsUrl).addTo(this.map);
        this.labels.setZIndex(2000);
      }

      if(basemapUrl) {
        this.router.setParams('basemap', basemap);
      }
    },

    _setAttributionControl: function() {
      this.attributionControl = this.map.attributionControl;
      this.attributionControl.customAttributions = [];
    },

    /**
     * Remove basemap from mapView
     */
    unsetBasemap: function() {
      if (this.basemap) {
        this.map.removeLayer(this.basemap);
      } else {
        console.info('Basemap doesn\`t exist.');
      }
    },

    /**
     * Render or remove layers by Layers Collection
     */
    renderLayers: function() {
      var layersData = this.layers.getPublished();

      _.each(layersData, function(layerData) {
        if (layerData.active) {
          if (layerData.maxZoom || layerData.minZoom) {

            if ( layerData.minZoom <= this.actualZoom && this.actualZoom <= layerData.maxZoom ) {
              this.layers.unsetDisabledByZoom(layerData.id);
              this._addingLayer(layerData);
              this._removeFromAdviseCollection(layerData);
            } else {
              this.removeLayer(layerData);
              this.layers.setDisabledByZoom(layerData.id);
              this._showAdvise(layerData);
            }

          } else {
            this._addingLayer(layerData);
          }

        } else {
          this._removingLayer(layerData);
        }
      }, this);

      //Set mask when journey map.
      if (this.model.get('journeyMap')) {
        this.setMaskLayer();
      }

      if(!this.finishedZooming) {
        this.checkMask();
      } else {
        this.finishedZooming = false;
      }
    },

    _addingLayer: function(layerData) {
      if (!layerData.order) {
        this._setOrder(layerData);
        this.addLayer(layerData);
      } else {
        this.addLayer(layerData);
      }
    },

    _removingLayer: function(layerData) {
      this._setOrderToNull(layerData);
      this.removeLayer(layerData);

      var currentLayerModel = _.findWhere(this.layers.models, { 'id': layerData });

      if (currentLayerModel) {
        currentLayerModel.set('active', false);
      }

      this._removeAttribution(layerData);
    },

    _showAdvise: function(layerData) {
      var layerModel = {
        "id": layerData.id,
        "name": layerData.name,
        "maxZoom": layerData.maxZoom,
        "minZoom": layerData.minZoom,
        "show": true
      };

      this.advise.currentZoom = this.actualZoom;

      if (!this.advise.collection.contains(layerModel)) {
        this.advise.collection.add([layerModel]);
      }
    },

    _removeFromAdviseCollection: function(layerData) {
      var currentModel = _.findWhere(this.advise.collection.models, { 'id': layerData.id });
      if (currentModel) {
        this.advise.collection.remove(currentModel);
      }
    },

    _setOrder: function(layer) {
      layer.order = this.layers.order || this.layers.getMaxOrderVal();
      this.layers.setOrder(layer.id);
    },

    _setOrderToNull: function(layerData){
      var layerId;
      var currentLayer;

      if (typeof layerData === 'object') {
        layerId = layerData.id;
        currentLayer = layerData;
      } else {
        layerId = layerData;
        currentLayer = _.findWhere(this.layers.models, { 'id': layerData });
      }

      currentLayer.order = null;
      this.layers.setOrderToNull(layerId);
    },

    /**
     * Add a layer instance to map
     * @param {Object} layerData
     */
    addLayer: function(layerData) {
      if (typeof layerData !== 'object' ||
        !layerData.id || !layerData.type) {
        throw 'Invalid "layerData" format.';
      }
      if (!this.map) {
        throw 'Create a map before add a layer.';
      }
      var layer = this.model.get(layerData.id);
      var layerInstance;

      if (!layer) {
        if(layerData.type) {
          var data = _.pick(layerData, ['sql', 'cartocss', 'interactivity']);
          var options = { sublayers: [data] };


          if(layerData.type === 'raster') {
            options = {
              sublayers: [ _.extend(data, { raster: true, raster_band: 1 }) ]
            };
          }

          layerInstance = new root.app.Helper.CartoDBLayer(this.map, options);
          layerInstance.create(function(layer) {
            layer.setOpacity(layerData.opacity);
            layer.setZIndex(1000 + layerData.order);
            this._setAttribution(layerData);
          }.bind(this));
        }

        if (layerInstance) {
          this.model.set(layerData.id, layerInstance);
        } else {
          throw 'Layer type hasn\'t been defined or it doesn\'t exist.';
        }
      } else {
        if (layer.layer) {
          layer.layer.setOpacity(layerData.opacity);
          layer.layer.setZIndex(1000 + layerData.order);
        }
        // console.info('Layer "' + layerData.id + '"" already exists.');
      }
    },

    _getFormattedAttribution: function(attribution) {
      return '<a target="_blank" href="' + attribution.url + '">' +
        attribution.name +'</a>';
    },

    /**
     * Set the attribution of the current layer
     * @param  {Object} layerData
     */
    _setAttribution: function(layerData) {
      var customAttributions = this.attributionControl.customAttributions,
        newAttributionText = '',
        newAttribution = {};


      if (!layerData.attributions) {
        return;
      }

      _.each(layerData.attributions, function(attr) {
        newAttribution = {
          name: attr.attributes.reference_short,
          url: attr.attributes.url,
          layer: layerData.id
        };

        newAttributionText = this._getFormattedAttribution(newAttribution);
        this.map.attributionControl.addAttribution(newAttributionText);
        customAttributions.push(newAttribution);
      }.bind(this))

    },

    /**
     * Removes attribution of the current layer
     * @param  {Object} layerData
     */
    _removeAttribution: function(layerData) {
      if (typeof layerData === 'object') {
        layerData = layerData;
      } else {
        layerData = _.findWhere(this.layers.models, { 'id': layerData }).attributes;
      }

      var customAttributions = this.map.attributionControl.customAttributions,
        attributionToRemove = {},
        textToRemove,
        removed = false;


      customAttributions.forEach(function(attribution, index) {
        if (!removed && layerData  && attribution.layer === layerData.id ) {
          textToRemove = this._getFormattedAttribution(attribution);
          customAttributions.splice(index, 1);
          removed = !removed;
        }
      }.bind(this));

      this.map.attributionControl.removeAttribution(textToRemove);
    },

    /**
     * Remove a specific layer on map
     * @param  {Object} layerData
     */
    removeLayer: function(layerData) {
      var layerId;

      if (typeof layerData === 'object') {
        layerId = layerData.id;
      } else {
        layerId = layerData;
      }

      var layerInstance = this.model.get(layerId);

      if (layerInstance) {
        this.model.set(layerId, null);
        layerInstance.remove();
      }
    },

    setMaskLayer: function(iso, opacity, searchMask) {
      var self = this;
      var countryIso = iso;

      if(!countryIso) {
        countryIso = this.model.get('countryIso');
      }

      this.checkMask();

      var maskLayer = new root.app.Helper.CartoDBmask(this.map, countryIso, {
        searchMask: searchMask
      });

      maskLayer.create(function(layer){
        layer.setZIndex(2000)

        if(opacity) {
          layer.setOpacity(opacity);
        }

        self.maskMapLayer = layer;
      });
    },

    getMapState: function() {
      var bounds = this.map.getBounds();

      return {
        bounds: {
          northEast: bounds._northEast,
          southWest: bounds._southWest
        },
        zoom: this.map.getZoom(),
        center: this.map.getCenter()
      }
    },

    checkMask: function() {
      if(this.maskMapLayer && !this.journeyMap) {
        this.map.removeLayer(this.maskMapLayer);
      }
    },

    setBbox: function(bbox) {
      if(bbox) {
        this.bbox = bbox;
        bbox = JSON.parse(bbox);
        var coords = bbox.coordinates[0];
        var southWest = L.latLng(coords[2][1], coords[2][0]),
          northEast = L.latLng(coords[0][1], coords[0][0]),
          bounds = L.latLngBounds(southWest, northEast);

        var maxZoom = this.map.getBoundsZoom(bounds, true);

        if(maxZoom > 9) {
          maxZoom = maxZoom - 3;
        } else if(maxZoom > 6) {
          maxZoom = maxZoom - 2;
        } else {
          maxZoom = maxZoom - 1;
        }

        this.map.fitBounds(bounds, { maxZoom: maxZoom });
      }
    },

    toggleLayers: function(show) {
      var layers = this.layers.getActiveLayers();
      var mapModel = this.model;

      if(!show) {
        this.zoomEndEvent = false;
      } else {
        this.zoomEndEvent = true;
        this.checkMask();
      }

      _.each(layers, function(layer) {
        var instance = mapModel.get(layer.id);

        if(instance) {
          if(show) {
            instance.layer.show();
          } else {
            instance.layer.hide();
          }
        }
      });
    },

    _setLayerBounds: function(layerId) {
      var mapModel = this.model;
      var instance = mapModel.get(layerId);

      if(instance) {
        instance.panToLayer();
      }
    }

  });

})(this);
