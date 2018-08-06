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
          return {
            id: -1,
            slug: 'predictive-model-layer',
            name: this.get('name'),
            type: 'cartodb',
            description: '{"description":"' + (this.get('description') || '') + '", "source":"' + (this.get('source') || '') + '"}',
            cartocss: '#intensification_reduce{\n\rpolygon-fill: #A53ED5;\n\rpolygon-opacity: 1;\n\rline-color: #A53ED5;\n\rline-width: 0.5;\n\rline-opacity: 1;\n}\n#intensification_reduce [ value <= 100] {\n\rpolygon-fill: #B10026;\n\rline-color: #B10026;\n}\n#intensification_reduce [ value <= 0.8] {\n\rpolygon-fill: #E31A1C;\n\rline-color: #E31A1C;\n}\n#intensification_reduce [ value <= 0.5] {\n\rpolygon-fill: #FC4E2A;\n\rline-color: #FC4E2A;\n}\n#intensification_reduce [ value <= 0.3] {\n\rpolygon-fill: #FD8D3C;\n\rline-color: #FD8D3C;\n}\n#intensification_reduce [ value <= 0.1] {\n\rpolygon-fill: #FEB24C;\n\rline-color: #FEB24C;\n}\n#intensification_reduce [ value <= 0.01] {\n\rpolygon-fill: #FED976;\n\rline-color: #FED976;\n}\n#intensification_reduce [ value <= 0] {\n\rpolygon-fill: #FFFFB2;\n\rline-color: #FFFFB2;\n}',
            interactivity: '',
            sql: 'select * from getModel(\'' + this.get('tableName') + '\', \'['
              + this.get('indicators')
                .filter(function (indicator) {
                  return indicator.value !== null && indicator.value !== undefined;
                })
                .map(function(ind) {
                  return '{ "column_name": "' + ind.column + '", "weight": ' + (ind.value % 1 === 0 ? ind.value : ind.value.toFixed(3)) + ', "operation": "' + (ind.operation || '+') + '" }';
                })
              + ']\')',
            color: '',
            opacity: 1,
            no_opacity: false,
            order: 1,
            maxZoom: 25,
            minZoom: 0,
            legend: '{"type": "choropleth",\r\n"min":"0",\r\n"mid": "0.5",\r\n"max":"1",\r\n"bucket":["#FFFFB2","#FED976","#FEB24C","#FD8D3C"," #FC4E2A","#E31A1C","#B10026"]}',
            group: -1,
            active: true,
            published: true,
            info: '{"description":"' + (this.get('description') || '') + '", "source":"' + (this.get('source') || '') + '"}',
            dashboard_order: null,
            download: false,
            dataset_shortname: null,
            dataset_source_url: null,
            attributions: false
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
          return l.analysisSuitable;
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
