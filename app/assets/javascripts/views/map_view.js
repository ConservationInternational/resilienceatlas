(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Map = Backbone.View.extend({

    defaults: {
      map: {
        zoom: 5,
        center: [40, -3]
      },
      basemap: {
        url: 'http://{s}.api.cartocdn.com/base-light/{z}/{x}/{y}.png'
      }
    },

    LayerModel: Backbone.Model.extend({}),

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = new this.LayerModel();
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
      if (!this.map) {
        this.map = L.map(this.el, this.options.map);
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
      var url = basemapUrl || this.options.basemap.url;
      this.basemap = L.tileLayer(url).addTo(this.map);
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
      var layer = this.layers.get(layerData.id), options;
      if (!layer) {
        switch(layerData.type) {
          case 'cartodb':
            options = _.pick(layerData, ['sql', 'cartocss', 'interactivity']);
            layerInstance = new root.app.Util.CartoDBLayer(this.map, options);
          break;
          default:
            layerInstance = null;
        }
        if (layerInstance) {
          this.layers.set(layer.id, layerInstance);
        } else {
          throw 'Layer type hasn\'t been defined or it doesn\'t exist.';
        }
      } else {
        console.info('Layer "' + layer.id + '"" already exists.');
      }
    },

    /**
     * Remove a specific layer on map
     * @param  {Object} layerData
     */
    removeLayer: function(layerData) {
      var layerInstance = this.layers.get(layerData.id);
      if (layerInstance) {
        layerInstance.remove();
      } else {
        console.info('Layer "' + layerData.id + '"" doesn\'t exist.');
      }
    }

  });

})(this);
