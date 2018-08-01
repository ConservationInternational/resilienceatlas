(function(root) {

  'use strict';

  root.app = root.app || {};

  root.app.ReportPageView = Backbone.Router.extend({


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.router = settings.router;
      this.subdomainParams = settings.subdomainParams;
      this.siteScopeId = settings.siteScopeId;

      this.initMap();
    },

    initMap: function() {
      var layersGroupsCollection = new root.app.Collection.LayersGroups();
      this.layersCollection = new root.app.Collection.Layers();
      var mapModel = new (Backbone.Model.extend({
        defaults: {
          countryIso: this.router.params.attributes && this.router.params.attributes.countryIso ? this.router.params.attributes.countryIso : null,
          maskSql: this.router.params.attributes && this.router.params.attributes.maskSql ? this.router.params.attributes.maskSql : null
        }
      }));

      // Predictive models
      this.predictiveModelsCollection = new root.app.Collection.Models(null, {
        siteScopeId: this.siteScopeId
      });
      this.activePredictiveModel = new (Backbone.Model.extend({
        /**
         * Return the layer corresponding to the parameter
         * of the model
         * @returns {object}
         */
        getLayer: function() {
          // FIXME: return the real layer
          return {
            "id": 6,
            "slug": "livelihood",
            "name": "Livelihoods zones",
            "type": "cartodb",
            "description": "{\"description\":\"Data from the GeoNetwork site of the Food and Agriculture Organisation of the UN; Also derived Famine Early Warning Systems Network (FEWSNet). Created by USAID in 1985, the Famine Early Warning Systems Network provides early warning and analysis on food insecurity.\", \"source\":\"FEWSNET. Livelihoods: Insights into how people survive and prosper [Internet]. [updated 21 January, 2015]. Available: https://www.fews.net/sectors/livelihoods [cited 21 October 2015].\", \"link\":\"http://www.fao.org/geonetwork/srv/en/main.home\" }",
            "cartocss": "#grp_africa_livelihoodzones {\r\n   polygon-opacity: 1;\r\n   line-width: 0;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Agro-Forestry\"] {\r\n   polygon-fill: #547D33;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Agro-Pastoral\"] {\r\n   polygon-fill: #81AF4B;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Arid\"] {\r\n   polygon-fill: #F6EED5;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Crops - Floodzone\"] {\r\n   polygon-fill: #7ADCC2;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Crops - Irrigated\"] {\r\n   polygon-fill: #67A1BD;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Crops - Rainfed\"] {\r\n   polygon-fill: #C6741D;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Fishery\"] {\r\n   polygon-fill: #255CB4;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"National Park\"] {\r\n   polygon-fill: #B0E5A0;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Pastoral\"] {\r\n   polygon-fill: #CDD13D;\r\n }\r\n #grp_africa_livelihoodzones[lz_type=\"Urban\"] {\r\n   polygon-fill: #6D6D6D;\r\n }\r\n #grp_africa_livelihoodzones {\r\n   polygon-fill: #947F4A;\r\n }",
            "interactivity": "",
            "sql": "SELECT the_geom, the_geom_webmercator,iso3,lz_type, lz_value FROM grp_africa_livelihoodzones\r\nunion\r\nSELECT the_geom, the_geom_webmercator,iso3,lz_type, lz_value FROM grp_asia_livelihoodzones",
            "color": "",
            "opacity": 1,
            "no_opacity": false,
            "order": 2,
            "maxZoom": 25,
            "minZoom": 0,
            "legend": "{\"type\": \"custom\",\r\n         \"data\": [\r\n           { \"name\": \"Agro-Forestry\", \"value\": \"#547D33\" },\r\n           { \"name\": \"Agro-Pastoral\", \"value\": \"#81AF4B\" },\r\n           { \"name\": \"Arid\", \"value\": \"#F6EED5\" },\r\n           { \"name\": \"Crops - Floodzone\", \"value\": \"#7ADCC2\" },\r\n           { \"name\": \"Crops - Irrigated\",\"value\": \"#67A1BD\" },\r\n           { \"name\": \"Crops - Rainfed\", \"value\": \"#C6741D\" },\r\n           { \"name\": \"Fishery\", \"value\": \"#255CB4\" },\r\n           { \"name\": \"National Park\", \"value\": \"#B0E5A0\" },\r\n           { \"name\": \"Pastoral\", \"value\": \"#CDD13D\" },\r\n           { \"name\": \"Urban\", \"value\": \"#6D6D6D\" },\r\n           { \"name\": \"Others\", \"value\": \"#947F4A\" }\r\n         ]\r\n       }",
            "group": 8,
            "active": true,
            "published": true,
            "info": "{\"description\":\"Data from the GeoNetwork site of the Food and Agriculture Organisation of the UN; Also derived Famine Early Warning Systems Network (FEWSNet). Created by USAID in 1985, the Famine Early Warning Systems Network provides early warning and analysis on food insecurity.\", \"source\":\"FEWSNET. Livelihoods: Insights into how people survive and prosper [Internet]. [updated 21 January, 2015]. Available: https://www.fews.net/sectors/livelihoods [cited 21 October 2015].\", \"link\":\"http://www.fao.org/geonetwork/srv/en/main.home\" }",
            "dashboard_order": null,
            "download": true,
            "download_url": "/users/login",
            "dataset_shortname": null,
            "dataset_source_url": null,
            "attributions": false
          };
        }
      }));

      var mapCenter = this.getMapCenter();
      var mapZoom = this.getMapZoom();

      this.mapView = new root.app.View.Map({
        el: '#mapView',
        layers: this.layersCollection,
        basemap: this.router.params.attributes.basemap,
        model: mapModel,
        predictiveModel: this.activePredictiveModel,
        router: this.router,
        subdomainParams: this.subdomainParams,
        options: {
          map: {
            zoom: this.router.params.attributes.zoom || mapZoom,
            minZoom: 2,
            maxZoom: 25,
            center: this.router.params.attributes.center ? [ JSON.parse(this.router.params.attributes.center).lat, JSON.parse(this.router.params.attributes.center).lng] : mapCenter,
            zoomControl: false,
            scrollWheelZoom: !this.embed ? true : false
          }
        }
      });

      // At begining create a map
      this.mapView.createMap();

      var legendView = new root.app.View.Legend({
        el: '#legendView',
        layers: this.layersCollection,
        model: new (Backbone.Model.extend({
          defaults: {
            hidden: false,
            order: []
          }
        })),
        predictiveModel: this.activePredictiveModel
      });

      // Fetching data
      var complete = _.invoke([
        layersGroupsCollection,
        this.layersCollection,
        this.predictiveModelsCollection
      ], 'fetch');

      $.when.apply($, complete).done(function() {
        // We restore the state of the report
        this.restoreState();

        // Render views
        legendView.render();
      }.bind(this));

    },

    getMapCenter: function() {
      if ( this.subdomainParams && !isNaN(this.subdomainParams.lat) && !!(this.subdomainParams.lat + 1) ) {
        return [this.subdomainParams.lat, this.subdomainParams.lng];
      } else {
        return [3.86, 47.28];
      }
    },

    getMapZoom: function() {
      if ( this.subdomainParams && !isNaN(this.subdomainParams.zoom_level) && !!(this.subdomainParams.zoom_level + 1) ) {
        return this.subdomainParams.zoom_level;
      } else {
        return 3;
      }
    },

    /**
     * Restore the state of the map and legend
     */
    restoreState: function() {
      var params = this.router.params.toJSON();

      // We first restore the state of the layers
      var layers;
      try {
        layers = JSON.parse(params.layers);
      } catch (e) {
        console.error('Unable to restore the layers', e);
        layers = [];
      }

      this.layersCollection.forEach(function(layerModel) {
        var layer = _.findWhere(layers, { id: layerModel.id });
        if (layer) {
          layerModel.set({
            active: true,
            opacity: layer.opacity,
            order: layer.order
          }, { silent: true });
        } else {
          layerModel.set({ active: false }, { silent: true });
        }
      });

      // We then restore the state of the model
      var serializedModel;
      try {
        serializedModel = JSON.parse(params.model);
      } catch(e) {
        console.error('Unable to restore the model', e);
        serializedModel = null;
      }

      if (serializedModel) {
        var model = this.predictiveModelsCollection.findWhere({ name: serializedModel.name }).toJSON();
        this.activePredictiveModel.set(model);

        for (var i = 0, j = serializedModel.values.length; i < j; i++) {
          var indicatorName = this.activePredictiveModel.get('indicators')[i].name;
          var indicatorRealValue = this.predictiveModelsCollection.getRealIndicatorValueFromIndex(serializedModel.values[i]);
          var indicatorHumanReadableValue = this.predictiveModelsCollection.getHumanReadableIndicatorValueFromIndex(serializedModel.values[i]);

          var model = _.extend({}, this.activePredictiveModel.attributes, {
            indicators: this.activePredictiveModel.attributes.indicators.map(function (indicator) {
              if (indicator.name !== indicatorName) {
                return indicator;
              }

              return _.extend({}, indicator, {
                value: indicatorRealValue,
                indexableValue: serializedModel.values[i],
                humanReadableValue: indicatorHumanReadableValue
              });
            })
          });

          this.activePredictiveModel.set(model, { silent: true });
        }
      }

      // We then restore the position of the map
      var zoom = params.zoom || 3;
      var center;
      try {
        center = JSON.parse(params.center);
      } catch(e) {
        console.error('Unable to restore the center of the map', e);
        center = { lat: 0, lng: 0 };
      }

      this.mapView.map.setView(center, zoom);

      // We then display the GeoJSON
      try {
        this.geojson = JSON.parse(params.geojson);
      } catch(e) {
        console.error('Unable to restore the geojson', e);
        this.geojson = null;
      }

      if (this.geojson) {
        Backbone.Events.trigger('map:draw:polygon', this.geojson);
        this.renderAnalysisContent();
      }

      // We finally display either the layers or the layer of the
      // predictive model
      var tab = params.tab || 'layers';
      if (tab === 'layers') {
        this.mapView.renderLayers();
      } else {;
        Backbone.Events.trigger('map:show:model');
      }
    },

    /**
     * Render the content of the analysis
     */
    renderAnalysisContent: function() {
      if (!this.activePredictiveModel.get('name')) {
        var activeLayers = this.layersCollection.getActived();
        var analyzableLayers = activeLayers.filter(function(l) {
          // TODO: implement the analysis for layers that aren't rasters
          return l.analysisSuitable && l.layerProvider === 'raster';
        });
        if (!analyzableLayers.length) {
          $('.js-analysis-content').html('None of the active layers can be analyzed.');
        } else {
          $('.js-analysis-content').html(
            '<div class="js-widgets"></div>'
            + (analyzableLayers.length !== activeLayers.length
              ? '<p>Some active layers can\'t be analyzed.</p>'
              : '')
          );

          var widgetsContainer = $('.js-widgets');
          analyzableLayers.forEach(function(layer) {
            new root.app.View.WidgetBarChart({
              el: widgetsContainer,
              slug: layer.slug,
              query: layer.analysisQuery,
              name: layer.name,
              geojson: this.geojson,
              hasLine: false,
              meta_short: layer.name,
              metadata: JSON.parse(layer.info),
              xAxisTickFormatter: d3.format('.3f'),
              verticalLabels: true
            });
          }.bind(this));
        }
      } else {

      }
    }
  });

})(this);
