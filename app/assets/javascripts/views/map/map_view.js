define([
  'underscore',
  'backbone',
  'leafletDraw',
  'models/map_model',
], function(_, Backbone, leaflet, MapModel) {

  'use strict';

  var MapView = Backbone.View.extend({

    defaults: {
      map: {
        center: [6.053161295714079, 49.5703125],
        zoom: 3,
        minZoom: 3,
        zoomControl: false,
        drawControl: false
      },
      bounds: {
        south: [-26.667095801104804, -15.8203125],
        north: [36.73888412439431, 115.400390625]
      },
      zoom: {
        position: 'topright'
      },
      draw: {
        position: 'topright',
        draw: {
          circle: false,
          rectangle: false,
          polyline: false,
          marker: false
        }
      }
    },

    tilesUrl: {
      satellite: 'http://server.arcgisonline.com' +
        '/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      terrain: 'http://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      topography: 'http://{s}.tile.osm.org/{z}/{x}/{y}.png'
    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : {};
      this.options = _.extend(this.defaults, this.options || {}, options);
      this.layers = settings.layers;
      this.model = new MapModel();
      this.createMap();
      this.setListeners();
      this.changeLayers();
    },

    setListeners: function() {
      this.listenTo(this.model, {
        'change:basemap': this.renderBasemap,
        'change:loadQueue': this.checkLoadQueue,
        'invalid': this.handlerError
      }, this);
      this.listenTo(this.layers, 'reset', this.changeLayers, this);

      Backbone.Events.on('layer:loading', this.addToLoadingQueue, this);
      Backbone.Events.on('layer:finishLoading', this.removeFromLoadingQueue, this);
    },

    createMap: function() {
      var southWest = L.latLng(this.options.bounds.south),
          northEast = L.latLng(this.options.bounds.north),
          bounds = L.latLngBounds(southWest, northEast);

      this.map = L.map(this.el, this.options.map);
      L.control.zoom(this.options.zoom).addTo(this.map)

      this.map.fitBounds(bounds);

      // drawing
      this.createMapControls();
      this.addDrawControl();
    },

    changeLayers: function() {
      var currentBasemap = this.layers.findWhere({
        type: 'basemap', active: true
      });

      this._layersActive = this._layersActive || {};

      // change basemap
      if (currentBasemap) {
        this.model.set('basemap', currentBasemap.attributes.slug, {
          validate: true
        });
      }

      // change layers
      var layers = _.clone(this.layers.models);
      var sortedLayers = _.sortBy(layers, function(layer){
        return layer.attributes.zindex;
      });

      _.each(sortedLayers, this.renderLayer, this);
    },

    renderLayer: function(layerModel) {
      if (layerModel.attributes.type === 'basemap') {
        return;
      }
      var latestLayer = this.model.get(layerModel.attributes.slug);
      if (latestLayer && layerModel.attributes.active !== true) {
        latestLayer.removeLayer();
        this.removeFromLoadingQueue(layerModel.attributes.slug);
        this.model.set(layerModel.attributes.slug, null, { silent: true });
      } else if (!latestLayer && layerModel.attributes.active === true) {
        var Instance = layerModel.attributes.Instance;

        if (Instance) {
          var layerInstance = new Instance({
            options: {
              interactivity: layerModel.attributes.interactivity,
              zIndex: layerModel.attributes.zindex,
              opacity: layerModel.attributes.opacity,
              slug: layerModel.attributes.slug,
              locateLayer: layerModel.attributes.locateLayer
            }
          });
          layerInstance.addLayer(this.map);
          this.model.set(layerModel.attributes.slug, layerInstance, {
            silent: true
          });
        } else {
          console.warn(
            '%1 layer doesn\'t exist'.format(layerModel.attributes.name)
          );
        }
      }
    },

    checkLoadQueue: function() {
      var queue = this.model.get('loadQueue');
      var $loader = $('#loader');

      if(queue.length > 0) {
        $loader.addClass('visible');
      } else {
        $loader.removeClass('visible');
      }
    },

    addToLoadingQueue: function(slug) {
      var queue = _.clone(this.model.get('loadQueue'));
      queue.push(slug);

      this.model.set('loadQueue', queue);
    },

    removeFromLoadingQueue: function(slug) {
      var queue = _.clone(this.model.get('loadQueue'));
      var index = queue.indexOf(slug);

      if(index > -1) {
        queue.splice(index, 1);
        this.model.set('loadQueue', queue);
      }
    },

    renderBasemap: function() {
      var tilesUrl = this.tilesUrl[this.model.get('basemap')];
      if (this.tileLayer) {
        this.tileLayer.setUrl(tilesUrl);
      } else {
        this.tileLayer = L.tileLayer(tilesUrl).addTo(this.map);
      }
    },

    handlerError: function(model, err) {
      console.error(err);
    },

    getMapState: function() {
      var bounds = this.map.getBounds();

      return {
        bounds: {
          northEast: bounds._northEast,
          southWest: bounds._southWest
        },
        zoom: this.map.getZoom()
      }
    },

    toggleSearch: function() {
      var $ele = this.$('.leaflet-control-search');

      if(!$ele.hasClass('active')) {
        $ele.addClass('active');
        Backbone.Events.trigger('search:show');
      } else {
        $ele.removeClass('active');
        Backbone.Events.trigger('search:hide');
      }
    },

    // DRAWING MANAGER //

    createMapControls: function() {
      L.Control.Analyze = L.Control.extend({
        options: {
          position: 'topright'
        },
        onAdd: _.bind(function () {
          var btnAnalyze = L.DomUtil.create('div',
            'leaflet-bar leaflet-control leaflet-control-custom leaflet-control-analyze');

          btnAnalyze.onclick = _.bind(function(){
            (!this.is_drawing) ? this.startDrawing() : this.stopDrawing();
          }, this );

          return btnAnalyze;
        }, this )
      });

      this.map.addControl(new L.Control.Analyze());

      L.Control.Search = L.Control.extend({
        options: {
          position: 'topright'
        },
        onAdd: _.bind(function () {
          var btnSearch = L.DomUtil.create('div',
            'leaflet-bar leaflet-control leaflet-control-custom leaflet-control-search');

          btnSearch.onclick = _.bind(function(e){
            L.DomEvent.preventDefault(e);
            L.DomEvent.stopPropagation(e);
            this.toggleSearch();
            return false;
          }, this );

          return btnSearch;
        }, this )
      });

      this.map.addControl(new L.Control.Search());
    },

    addDrawControl: function() {
      this.drawnItems = new L.FeatureGroup();
      var options = _.extend(this.options.draw, {
        edit: {
          featureGroup: this.drawnItems
        }
      });

      this.map.addLayer(this.drawnItems);
      this.drawingListeners();
    },

    drawingListeners: function(){
      this.map.on('draw:drawstop', _.bind(function (e) {
        if(!this.complete){
          this.is_drawing = false;
          this.toggleAnalyzeBtn(false);
        }
      }, this ));

      this.map.on('draw:created', _.bind(function (e) {
        this.toggleAnalyzeBtn(true);
        this.completedDrawing(e);
      }, this ));

      this.map.on('draw:drawstart', _.bind(function (e) {
        this.toggleAnalyzeBtn(true);
        this.drawnItems.clearLayers();
      }, this ));


      Backbone.Events.on('analysis:delete', this.stopDrawing, this);
    },

    toggleAnalyzeBtn: function(to){
      $('.leaflet-control-analyze').toggleClass('active', to);
    },

    startDrawing: function(){
      this.is_drawing = true;
      this.polygon = new L.Draw.Polygon(this.map, {
          showArea: true,
          shapeOptions: {
            color: '#00BDFF'
          }
        });
      this.polygon.enable();
    },

    stopDrawing: function(){
      this.complete = false;
      this.is_drawing = false;
      // Remove polygon either is drawing or is drawed.
      this.polygon.disable();
      this.drawnItems.clearLayers();
      this.removePolygonBtn();

      this.toggleAnalyzeBtn(false);

      $('#analyze-polygon').removeClass('active').css({ left: 0, top: 0 });

      Backbone.Events.trigger('drawing:delete');
    },

    completedDrawing: function(e){
      this.complete = true;
      this.analyzelayer = e.layer;
      this.drawnItems.addLayer(this.analyzelayer);
      this.placeAnalyzeBtn(this.analyzelayer);

      // Events
      this.analyzelayer.on("click", _.bind(function (e) {
        this.removePolygonBtn();
        Backbone.Events.trigger('drawing:analyze',this.analyzelayer);
      }, this ));
    },

    placeAnalyzeBtn: function(layer){
      L.LabelOverlay = L.Class.extend({
        initialize: function(latLng,label,options) {
            this._latlng = latLng;
            this._label = label;
            L.Util.setOptions(this, options);
        },
        options: {
            offset: new L.Point(0, 2)
        },
        onAdd: function(map) {
            this._map = map;
            if (!this._container) {
                this._initLayout();
            }
            map.getPanes().overlayPane.appendChild(this._container);
            this._container.innerHTML = this._label;
            map.on('viewreset', this._reset, this);
            this._reset();
        },
        onRemove: function(map) {
            map.getPanes().overlayPane.removeChild(this._container);
            map.off('viewreset', this._reset, this);
        },
        _reset: function() {
            var pos = this._map.latLngToLayerPoint(this._latlng);
            var op = new L.Point(pos.x, pos.y);
            L.DomUtil.setPosition(this._container, op);
        },
        _initLayout: function() {
            this._container = L.DomUtil.create('div', 'leaflet-btn-analysis');
        }
      });

      var center = layer.getBounds().getCenter();
      this.polygonBtn = new L.LabelOverlay(center, '<button class="leaflet-analyze-custom button round tiny">Analyze</button>');
      this.map.addLayer(this.polygonBtn);

    },

    removePolygonBtn: function(){
      if (this.polygonBtn) {
        this.polygonBtn.onRemove(this.map);
        this.polygonBtn = null;
      }
    }
    // END DRAWING MANAGER //



  });

  return MapView;

});
