(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Map = Backbone.View.extend({

    defaults: {
      map: {
        zoom: 4,
        center: [35.947265625, 7.710991655433229],
        zoomControl: false,
        scrollWheelZoom: false
      },
      basemap: {
        url: 'http://{s}.api.cartocdn.com/base-light/{z}/{x}/{y}.png'
      },
      zoomControl: {
        position: 'topright'
      }
    },

    model: new (Backbone.Model.extend({})),

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.layers = settings.layers;
      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.layers, 'change', this.renderLayers);
    },

    /**
     * Instantiates a Leaflet map object
     */
    createMap: function() {
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
     * Render or remove layers by Layers Collection
     */
    renderLayers: function() {
      var self = this;
      var renderEachLayer = function() {
        var layersData = _.where(this.layers.toJSON(), { published: true });
        _.each(layersData, function(layerData) {
          console.log(layerData.slug, layerData.active);
          if (layerData.active) {
            self.addLayer(layerData);
          } else {
            self.removeLayer(layerData);
          }
        });
      };

      // It will fetch layers data when layersData object is empty
      if (this.layers.length === 0) {
        this.layers.fetch().done(renderEachLayer.bind(this));
      } else {
        renderEachLayer.call(this);
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
        console.info('Layer "' + layerData.id + '"" already exists.');
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
      } else {
        console.info('Layer "' + layerData.id + '"" doesn\'t exist.');
      }
    }

  });

})(this);
