(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Map = Backbone.View.extend({

    defaults: {
      // map: {
      //   center: [0, 15],
      //   zoomControl: false,
      //   scrollWheelZoom: false
      // },
      defaultBasemap: 'defaultmap',
      basemap: {
        labels: 'http://api.tiles.mapbox.com/v4/cigrp.829fd2d8/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g',
        defaultmap: 'http://api.tiles.mapbox.com/v4/cigrp.2ad62493/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g',
        satellite: 'http://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        topographic: 'http://server.arcgisonline.com/ArcGIS/rest/services/World_Physical_Map/MapServer/tile/{z}/{y}/{x}'
      },
      zoomControl: {
        position: 'topright'
      }
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.router = settings.router;
      this.layers = settings.layers;
      this.selectedBasemap = settings.basemap;
      this.setListeners();

      this.journeyMap = this.model.get('journeyMap');
    },

    setListeners: function() {
      this.listenTo(this.layers, 'change', this.renderLayers);
      // this.listenTo(this.layers, 'sort', this.renderLayers);

      Backbone.Events.on('basemap:change', _.bind(this.selectBasemap, this));
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
      var self = this;
      // trampita zoom
      if (this.journeyMap) {
        if ( $(document).width() < 1020 ) {
          this.options.map.zoom = 5;
          this.options.map.center = [8, 35]; //Horn of Africa
        } else {
          this.options.map.zoom = 6;
          this.options.map.center = [9, 37]; //Horn of Africa
        }
      }
      if (!this.map) {
        this.map = L.map(this.el, this.options.map);
        this.map.on('click', function(){
          self.checkMask();
        });
        if (this.options.zoomControl) {
          this.addControlZoom();
        }
        this.setBasemap();
      } else {
        console.info('Map already exists.');
      }

      var self = this;

      this.actualZoom = this.options.map.zoom;

      this.map.on('zoomend', _.bind(function() {
        this.actualZoom = this.map.getZoom();
        this.router.setParams('zoom', this.actualZoom);
        this.finishedZooming = true;
        this.renderLayers();
      }, this));

      this.map.on('dragend', _.bind(function() {
        this.actualCenter = this.map.getCenter();
        this.router.setParams('center', this.actualCenter);
      }, this));
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
      var newBasemapUrl = this.options.basemap[basemapType];
      this.setBasemap(newBasemapUrl, basemapType);
    },

    _getBaseMapUrl: function() {
      var basemap = this.options.basemap.defaultmap;

      if(this.selectedBasemap) {
        basemap = this.options.basemap[this.selectedBasemap];
      }

      return basemap;
    },

    /**
     * Add a basemap to map
     * @param {String} basemapUrl http://{s}.tile.osm.org/{z}/{x}/{y}.png
     */
    setBasemap: function(basemapUrl, type) {
      if (!this.map) {
        throw 'Map must exists.';
      }
      if (this.basemap) {
        this.map.removeLayer(this.basemap);
      }

      var labelsUrl = this.options.basemap.labels;
      var url = basemapUrl || this._getBaseMapUrl();
      var basemap = type || this.selectedBasemap || this.options.defaultBasemap;

      if (this.journeyMap) {
        this.basemap = L.tileLayer(url).addTo(this.map);
      } else {
        this.basemap = L.tileLayer(url).addTo(this.map);
        this.labels = L.tileLayer(labelsUrl).addTo(this.map);
        this.labels.setZIndex(1005);
      }

      if(basemapUrl) {
        this.router.setParams('basemap', basemap);
      }
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

      //Test for zoom scope.
      _.each(layersData, function(layerData) {
        if (layerData.id == 31) {
          layerData.maxZoom = 100;
          layerData.minZoom = 3;
        }

        if (layerData.id == 36) {
          layerData.maxZoom = 3;
          layerData.minZoom = 0;
        }

        if (layerData.active) {
          if (layerData.maxZoom) {
            if ( layerData.minZoom <= this.actualZoom && this.actualZoom <= layerData.maxZoom ) {
              this.addLayer(layerData)
              this.layers.unsetDisabledByZoom(layerData.id)
            } else {
              this.removeLayer(layerData);
              this.layers.setDisabledByZoom(layerData.id);
            }
          } else {
            this.addLayer(layerData);
          }
        } else {
          this.removeLayer(layerData);
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

    // _manageCssClasses: function(layerId) {

    // },

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
        switch(layerData.type) {
          case 'cartodb':
            var data = _.pick(layerData, ['sql', 'cartocss', 'interactivity']);
            var options = { sublayers: [data] };
            layerInstance = new root.app.Helper.CartoDBLayer(this.map, options);
            layerInstance.create(function(layer) {
              layer.setOpacity(layerData.opacity);
              layer.setZIndex(1000-layerData.order);
            });
          break;
          case 'raster':
            var data = _.pick(layerData, ['sql', 'cartocss', 'interactivity']);
            var options = {
              sublayers: [ _.extend(data, { raster: true, raster_band: 1 }) ]
            };
            layerInstance = new root.app.Helper.CartoDBRaster(this.map, options);
            //When carto bug solved, only back to create method.
            layerInstance.createRasterLayer(function(layer) {
              layer.setOpacity(layerData.opacity);
              layer.setZIndex(1000-layerData.order);
            });
          break;
          default:
            layerInstance = null;
        }
        if (layerInstance) {
          this.model.set(layerData.id, layerInstance);
        } else {
          throw 'Layer type hasn\'t been defined or it doesn\'t exist.';
        }
      } else {
        if (layer.layer) {
          layer.layer.setOpacity(layerData.opacity);
          layer.layer.setZIndex(1000-layerData.order);
        }
        // console.info('Layer "' + layerData.id + '"" already exists.');
      }
    },

    /**
     * Remove a specific layer on map
     * @param  {Object} layerData
     */
    removeLayer: function(layerData) {
      var layerInstance = this.model.get(layerData.id);
      if (layerInstance) {
        this.model.set(layerData.id, null);
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
        layer.setZIndex(1001)

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
        bbox = JSON.parse(bbox);
        var coords = bbox.coordinates[0];
        var southWest = L.latLng(coords[2][1], coords[2][0]),
          northEast = L.latLng(coords[0][1], coords[0][0]),
          bounds = L.latLngBounds(southWest, northEast);

        this.map.fitBounds(bounds);
      }
    }

  });

})(this);
