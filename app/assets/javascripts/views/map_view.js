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
        url: 'http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
      },
      journeyBasemap: {
        url: 'https://grp.global.ssl.fastly.net/user/grp/api/v1/map/4b5a4ae5b323de21bd4b3716b6293598:1440586478249.0498/0/{z}/{x}/{y}.png'
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
    },

    setListeners: function() {
      this.listenTo(this.layers, 'change', this.renderLayers);
      // this.listenTo(this.layers, 'sort', this.renderLayers);
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
      // trampita zoom
      if (this.model.get('journeyMap')) {
        this.options.map.zoom = 6;
        this.options.map.center = [8, 37]; //Horn of Africa
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

      //basemap depends on if it is embed or not.
      //Add here mapbox basemap url.
      var customUrl = this.model.get('journeyMap') ? null : this.options.basemap.url;
      //Just in case a basemapUrl is given into the method call.
      var url = basemapUrl || customUrl;

      if (customUrl) {
        this.basemap = L.tileLayer(url).addTo(this.map);
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

      var maskLayer = new root.app.Helper.CartoDBmask(this.map);

      maskLayer.create(function(layer){
        layer.setZIndex(1001)
      });
    }

  });

})(this);
