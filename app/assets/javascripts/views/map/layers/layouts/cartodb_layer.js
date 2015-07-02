define([
  'underscore',
  'lib/class',
  'text!templates/map/custom_map_info_window.handlebars'
], function(_, Class, infoWindowTPL) {

  'use strict';

  var CartoDBLayer = Class.extend({

    defaults: {
      username: 'cigrp'
    },

    cartoLegends: {},

    init: function(settings) {
      var options = settings && settings.options ? settings.options : {};
      this.options = _.extend(this.defaults, this.options || {}, options);
    },

    /**
     * Add a layer to map
     * @param  {Object} map
     */
    addLayer: function(map) {
      var self = this;
      var options = _.clone(this.options);
      var slug = options.slug;
      this.map = map;

      Backbone.Events.trigger('layer:loading', slug);

      if(!options.params.raster) {
        this.renderLayer(options);
      } else {
        this.renderRaster(options);
      }
    },

    renderLayer: function(options) {
      var self = this;
      var map = this.map;
      var zindex = options.zIndex;
      var opacity = options.opacity;
      var interactivity = options.interactivity;
      var locateLayer = options.locateLayer;

      var cartoParams = {
        user_name: this.defaults.username,
        type: 'cartodb',
        sublayers: [{
          sql: options.params.q,
          cartocss: options.params.cartocss,
          interactivity: interactivity
        }]
      }

      cartodb.createLayer(map, cartoParams)
      .addTo(map)
      .done(function(layer) {
        layer.setZIndex(zindex);
        layer.setOpacity(opacity);
        self.layer = layer;

        layer.bind('load', function() {
          Backbone.Events.trigger('layer:finishLoading', options.slug);
        });

        if(locateLayer) {
          var sql = new cartodb.SQL({ user: options.username});
          sql.getBounds(options.params.q).done(function(bounds) {
            self.bounds = bounds;
          });
        }

        if(interactivity) {
          self.addInfoWindow(interactivity);
        }

        if(options.params.legend) {
          self.addLegend(options);
        }
      });
    },

    renderRaster: function(options) {
      var self = this;
      var config = {
        layers: [{
          type: 'cartodb',
          options: {
            sql: options.params.q,
            cartocss: options.params.cartocss,
            cartocss_version: '2.3.0',
            geom_column: 'the_raster_webmercator',
            geom_type: 'raster'
          }
        }]
      };
      var url = 'http://'+this.defaults.username+'.cartodb.com/api/v1/map';
      $.ajax({
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        url: url,
        data: JSON.stringify(config),
        success: function(response) {
          var layergroup = response;
          var tilesEndpoint = url + '/' + layergroup.layergroupid + '/{z}/{x}/{y}.png';
          var protocol = 'https:' === document.location.protocol ? 'https' : 'http';

          if (layergroup.cdn_url && layergroup.cdn_url[protocol]) {
            var domain = layergroup.cdn_url[protocol];
            if ('http' === protocol) {
              domain = '{s}.' + domain;
            }
            tilesEndpoint = protocol + '://' + domain + '/' + self.defaults.username + '/api/v1/map/' + layergroup.layergroupid + '/{z}/{x}/{y}.png';
          }

          self.layer = L.tileLayer(tilesEndpoint, {
          }).addTo(self.map);

          self.layer.on('load', function() {
            Backbone.Events.trigger('layer:finishLoading', options.slug);
          });
        },
        error: function(){
          Backbone.Events.trigger('layer:finishLoading', options.slug);
        }
      });
    },

    /**
     * Removes a layer
     */
    removeLayer: function() {
      if (this.map && this.layer) {
        this.map.removeLayer(this.layer);
      }

      this.renderCartoLegends();
    },

    updateLayer: function() {
      this.removeLayer();
      this.addLayer(this.map);
    },

    panToLayer: function() {
      var bounds = this.bounds;

      if(bounds) {
        this.map.fitBounds(bounds, {maxZoom: this.map.getZoom()});
      }
    },

    addLegend: function(options) {
      var dataLegend = [
        { value: options.params.legend.min },
        { value: options.params.legend.max }
      ];

      _.each(options.params.legend.bucket, function(bucket, i) {
        dataLegend.push({
          name: "color"+i,
          value: bucket
        })
      });

      this.legend = new cdb.geo.ui.Legend({
         type: options.params.legend.type,
         data: dataLegend
       });

      var legendHtml = this.legend.render().el;
      var currentSlug = options.slug;

      this.keepCartoLegend(currentSlug, legendHtml);


    },

    keepCartoLegend: function(currentSlug, legendHtml) {
      this.cartoLegends[currentSlug] = legendHtml;

      this.renderCartoLegends();
    },

    renderCartoLegends: function() {
      if (!_.isEmpty(this.cartoLegends)) {
        $.each(this.cartoLegends, function(slug, legend) {
          $('#legend-'+slug).html(legend);
        });
      }
    },

    addInfoWindow: function(interactivity) {
      if(this.infoWindow) {
        this.infoWindow.remove();
      }

      var sublayer = this.layer.getSubLayer(0);
      var columns = _.allKeys(interactivity);
      var names = JSON.stringify(_.values(interactivity));
      var tpl = '<% var colNames = %1 %>'.format(names) + infoWindowTPL;

      this.infoWindow = cdb.vis.Vis.addInfowindow(this.map,
        sublayer,
        columns, {
          infowindowTemplate: tpl,
          templateType: 'underscore',
        });
    }

  });

  return CartoDBLayer;

});
