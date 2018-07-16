(function(root) {

  'use strict';

  root.app = root.app || {};

  root.app.MapPageView = Backbone.Router.extend({


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.setListeners();

      this.router = settings.router;
      this.subdomainParams = settings.subdomainParams;
      this.embed = settings.embed || false;

      this.initMap();
    },

    setListeners: function() {
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

    initMap: function() {
      var journeyMap = this._checkJourneyMap();
      var toolbarView = new root.app.View.Toolbar();
      var layersGroupsCollection = new root.app.Collection.LayersGroups();
      var layersCollection = new root.app.Collection.Layers();
      var mapModel = new (Backbone.Model.extend({
        defaults: {
          journeyMap: journeyMap,
          countryIso: this.router.params.attributes && this.router.params.attributes.countryIso ? this.router.params.attributes.countryIso : null,
          maskSql: this.router.params.attributes && this.router.params.attributes.maskSql ? this.router.params.attributes.maskSql : null
        }
      }));

      // Predictive models
      var predictiveModelsCollection = new root.app.Collection.Models();
      var activePredictiveModel = new (Backbone.Model.extend({
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

      var mapView = new root.app.View.Map({
        el: '#mapView',
        layers: layersCollection,
        basemap: this.router.params.attributes.basemap,
        model: mapModel,
        predictiveModel: activePredictiveModel,
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
      mapView.createMap();

      // We init the sidebar after the map so the sidebar
      // can tell the map its initial state and offset it
      var sidebarView = new root.app.View.Sidebar({
        router: this.router,
        subdomainParams: this.subdomainParams,
        predictiveModelsCollection: predictiveModelsCollection,
        predictiveModel: activePredictiveModel,
        layers: layersCollection
      });

      //No Layer list nor legend are showed into journey embed map.
      if (!journeyMap) {
        var layersListView = new root.app.View.LayersList({
          el: '#layersListView',
          layers: layersCollection,
          subdomainParams: this.subdomainParams
        });

        var predictiveModelView = new root.app.View.PredictiveModels({
          el: '#modelContent',
          collection: predictiveModelsCollection,
          model: activePredictiveModel,
          router: this.router
        });

        var legendView = new root.app.View.Legend({
          el: '#legendView',
          layers: layersCollection,
          model: new (Backbone.Model.extend({
            defaults: {
              hidden: false,
              order: []
            }
          })),
          predictiveModel: activePredictiveModel
        });
      }

      // Fetching data
      var complete = _.invoke([
        layersGroupsCollection,
        layersCollection
      ], 'fetch');

      $.when.apply($, complete).done(function() {

        // Checking routes and setting actived layers
        var routerParams = _.isEmpty(this.router.params.attributes);
        if (!routerParams && this.router.params.attributes.layers) {
          var activedLayers = JSON.parse(this.router.params.attributes.layers);
          var activedLayersIds = _.pluck(activedLayers, 'id');
          _.each(layersCollection.models, function(model) {
            var routerLayer = _.findWhere(activedLayers, { id: model.id });
            var active = _.contains(activedLayersIds, model.id);
            var layerData = { active: active };
            if (routerLayer) {
              layerData.opacity = routerLayer.opacity;
              layerData.order = routerLayer.order;
            }
            model.set(layerData, { silent: true });
          });
          layersCollection.sort();
        } else if (routerParams) {
          var data = layersCollection.getActived();
          this.router.setParams('layers', data, ['id', 'opacity', 'order']);
        }

        // Updating URL when layers collection change
        layersCollection.on('change', function() {
          var data = layersCollection.getActived();
          this.router.setParams('layers', data, ['id', 'opacity', 'order']);
        }.bind(this));

        // Attach groups to layers collection
        layersCollection.setGroups(layersGroupsCollection);

        // Render views
        mapView.renderLayers();
        //Layer list is not showed into journey embed map.
        if (!journeyMap) {
          layersListView.render();
          legendView.render();
        }

        var socialShare = new root.app.View.Share({
          'map': mapView,
          layers: layersCollection
        });

        if (!journeyMap) {
          var searchView = new root.app.View.Search({
            el: '#toolbarView',
            map: mapView
          });
        }

      }.bind(this));
    },

    _checkJourneyMap: function() {
      return $('body').hasClass('is-journey-map');
    },


  });

})(this);
