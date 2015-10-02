(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Map = Backbone.View.extend({

    defaults: {
      map: {
        zoom: 3,
        center: [0, 15],
        // center: [10, 30], //Horn of Africa
        zoomControl: false,
        scrollWheelZoom: false
      },
      basemap: {
        //This one below is the journeys one.
        // url: 'https://grp.global.ssl.fastly.net/user/grp/api/v2/viz/ff7bef12-4d7b-11e5-86c7-0e48d404cb93/viz.json',
        url: 'http://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png',
        labels: 'http://api.tiles.mapbox.com/v4/cigrp.829fd2d8/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g'
      },
      journeyBasemap: {
        // url: 'http://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png'
        url: 'https://grp.global.ssl.fastly.net/user/grp/api/v2/viz/ff7bef12-4d7b-11e5-86c7-0e48d404cb93/viz.json'
      },
      zoomControl: {
        position: 'topright'
      }
    },


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this.setListeners();

      this.journeyMap = this.model.get('journeyMap');
      this.currentCountry = this.model.get('countryIso') || null;
    },

    setListeners: function() {
      this.listenTo(this.layers, 'change', this.renderLayers);
      // this.listenTo(this.layers, 'sort', this.renderLayers);
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
      // trampita zoom I know there is a better way to do it...
      //but... you know...
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
        this.map = L.map(this.el, this.options.map);
        if (this.options.zoomControl) {
          this.addControlZoom();
        }
        this.setBasemap();
      } else {
        console.info('Map already exists.');
      }
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

    /**
     * Add a basemap to map
     * @param {String} basemapUrl http://{s}.tile.osm.org/{z}/{x}/{y}.png
     */
    setBasemap: function(basemapUrl) {
      if (!this.map) {
        throw 'Map must exists.';
      }
      if (this.basemap) {
        this.map.removeLayer(this.basemap);
      }

      //basemap depends on if it is journey embed or not.
      var customUrl = this.journeyMap ? this.options.journeyBasemap.url : this.options.basemap.url;
      var labelsUrl = this.options.basemap.labels;
      //Just in case a basemapUrl is given into the method call.
      var url = basemapUrl || customUrl;

      if (this.journeyMap) {
        this.basemap = cartodb.createLayer(this.map, url).addTo(this.map);
      } else {
        // this.basemap = cartodb.createLayer(this.map, url).addTo(this.map);
        this.basemap = L.tileLayer(url).addTo(this.map);
        this.labels = L.tileLayer(labelsUrl).addTo(this.map);
        this.labels.setZIndex(1005);
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
      _.each(layersData, function(layerData) {
        if (layerData.active) {
          this.addLayer(layerData);
        } else {
          this.removeLayer(layerData);
        }
      }, this);

      //Set mask when journey map.
      if (this.model.get('journeyMap')) {
        this.setMaskLayer();
      }

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

    setMaskLayer: function() {
      var countryIso = this.model.get('countryIso');
      var maskLayer = new root.app.Helper.CartoDBmask(this.map, countryIso);

      maskLayer.create(function(layer){
        layer.setZIndex(1001)
      });
    }

  });

})(this);
