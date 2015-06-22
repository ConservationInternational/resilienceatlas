define([
  'underscore',
  'd3',
  'lib/class'
], function(_, d3, Class) {

  'use strict';

  var D3Layer = Class.extend({

    getData: function() {
      var url = this.options.url;
      var params = this.options.params;
      var uri = new URI(url).search(params);
      return $.get(uri.href());
    },

    /**
     * Transform JSON to GeoJSON
     * @param  {Array} data
     * @return {Object}
     */
    toGeoJSON: function(data) {
      var geojson = {
        type: 'FeatureCollection',
        features: _.map(data, function(d) {
          var properties = _.clone(d);
          if (properties.geom) {
            delete properties.geom;
          }
          return {
            type: 'Feature',
            geometry: JSON.parse(d.geom),
            properties: properties
          };
        })
      };
      return geojson;
    },

    /**
     * Draw layer, this method doesn't need add layer
     * @param  {Object} map
     * @param  {Object} geojson
     * @return {Object} feature
     */
    addLayer: function(map, geojson) {
      this.map = map;

      function projectPoint(x, y) {
        var point = map.latLngToLayerPoint(new L.LatLng(y, x));
        this.stream.point(point.x, point.y);
      }

      var svg = this.svg = d3.select(map.getPanes().overlayPane).append('svg');
      var g = svg.append('g').attr('class', 'leaflet-zoom-hide');
      var transform = d3.geo.transform({ point: projectPoint });
      var path = d3.geo.path().projection(transform);
      var feature = g.selectAll('path')
        .data(geojson.features)
        .enter().append('path');

      function draw() {
        var bounds = path.bounds(geojson),
            topLeft = bounds[0],
            bottomRight = bounds[1];
        var translate = 'translate(%1, %2)'.format(-topLeft[0], -topLeft[1]);

        svg.attr('width', bottomRight[0] - topLeft[0])
          .attr('height', bottomRight[1] - topLeft[1])
          .style('left', '%1px'.format(topLeft[0]))
          .style('top', '%1px'.format(topLeft[1]));

        g.attr('transform', translate);

        feature.attr('d', path);
      }

      draw();

      map.on('viewreset', draw);

      return feature;
    },

    /**
     * Method to remove a D3 Layer
     */
    removeLayer: function() {
      if (this.svg) {
        this.svg.remove();
      }
    }

  });

  return D3Layer;

});
