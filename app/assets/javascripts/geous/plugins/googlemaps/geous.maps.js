/**
 *  Geous/Google Maps integration
 *
 *  This plugin remains very much under development. Use at your own risk!
 */
;(function (geous) {

    'use strict';

    var plugin = geous.gmap = {};

    /**
     *  The horrific offspring of a `google.maps.marker` and a `geous.Location`
     *
     *  Options include
     *  - location
     *  - marker
     */
    plugin.locationMarker = function (opts) {

        var defaults = {
                location: null,
                marker: null
            };

        geous.extend(this, defaults, opts);

        this.setIcon = function (icon) {
            this.marker.setIcon(icon);
        }

        this.setTitle = function (title) {
            this.marker.setTitle(title);
        }
    }

    /**
     *  A collection of `locationMarkers`
     */
    plugin.locationMarkerCollection = function (opts) {

        var _markers = [];

        geous.extend(this, geous.Events);

        /**
         *  The number of elements in this collection
         *  @type   {Number}
         */
        this.length = 0;

        /**
         *  Add a Location to this collection
         *  @param  {geous.Location}    location    the location to add
         */
        this.add = function (location, opts) {

            var marker;

            if (this.contains(location)) return;

            marker = new plugin.locationMarker({
                location: location
            });

            _markers.push(marker);
            this.length++;
            this.trigger('add', marker, opts);

            return marker;
        }

        /**
         *  Call a function on each location in this collection
         *  @param  {Function}  callback    the function to call
         */
        this.each = function (callback) {

            var i = 0,
                m;

            while (m = _markers[i++]) {
                if (callback.call(this, m) === false) break;
            }
        };

        /**
         *  Check whether this collection contains the given location
         *  @param  {geous.Location}    location    the location to check for
         *  @return {Boolean}
         */
        this.contains = function (location) {
            return (this.find(location) !== -1);
        }

        /**
         *  Retrieve a given location from this collection
         *  @param  {geous.Location}    location    the location to check for
         *  @return {Number}
         */
        this.get = function (location) {
            var index = this.find(location);
            if (index > -1) return _markers[index];
            return null;
        }

        /**
         *  Find the index of a given location within this collection
         *  @param  {geous.Location}    location    the location to check for
         *  @return {Number}
         */
        this.find = function(location) {
            var i = 0, 
                m;
            while (m = _markers[i++]) {
                if (m.location && m.location === location) {
                    return i - 1;
                }
            }
            return -1;
        }

        /**
         *  Remove a Location from this collection
         *  @param  {geous.Location}    location    the location to remove
         */
        this.remove = function(location) {

            var index = this.find(location),
                marker;

            if (index < 0) return;

            marker = _markers.splice(index, 1);
            this.length--;
            this.trigger('remove', marker[0]);
        }

        /**
         *  Remove all Locations from this collection
         */
        this.empty = function() {
            var m;
            while (m = _markers[0]) {
                this.remove(m.location);
            }
        }

        this.bounds = function() {

            var bounds = {
                    sw: [90, 180],
                    ne: [-90, -180]
                };

            this.each(function (locationMarker) {

                var coords = locationMarker.location.coordinates;

                if (coords.lat > bounds.ne[0]) bounds.ne[0] = coords.lat;
                if (coords.lng > bounds.ne[1]) bounds.ne[1] = coords.lng;
                if (coords.lat < bounds.sw[0]) bounds.sw[0] = coords.lat;
                if (coords.lng < bounds.sw[1]) bounds.sw[1] = coords.lng;
            });
    
            return bounds;
        }
    }

    plugin.locationInfo = function (opts) {

        var defaults = {
                location: null,
                map: null
            };

        geous.extend(this, defaults, opts);

        this.show = function (opts) {
        }

        this.hide = function () {

        }
    }

    /**
     *  Extend google.maps.Map with a few handy helper functions
     *
     */
    var _mapPrototype = {

        /**
         *  Provide detailed content on a particular location
         *
         *  @param  {geous.Location}    location    the location
         *  @param  {String|DOMNode=}   content the HTML content to add
         */
        detail: function (location, content) {

            var dialog,
                locationMarker;

            if (!(this.locations instanceof plugin.locationMarkerCollection)) return;

            if (locationMarker = this.locations.get(location)) {
                if (content || (content = locationMarker.location.detail)) {
                    dialog = new google.maps.InfoWindow({content: content});
                    dialog.open(this, locationMarker.marker);
                }
            } else {

                // add marker and locate?
                if (content || (content = location.detail)) {

                    dialog = new google.maps.InfoWindow({
                        content: content,
                        position: new google.maps.LatLng(
                            location.coordinates.lat,
                            location.coordinates.lng
                        )
                    });
        
                    dialog.open(this);
                }
            }
        },

        /**
         *  Scale the map to fit all locations in its current location collection
         *
         *  @param  {plugin.locationMarkerCollection=}  userLocations   locations to fit
         */
        fitToLocations: function (userLocations) {

            var bounds,
                locations = userLocations || this.locations,
                ne,
                sw;

            if (!(locations instanceof plugin.locationMarkerCollection)) return;

            bounds = locations.bounds();
            ne = new google.maps.LatLng(bounds.ne[0], bounds.ne[1]);
            sw = new google.maps.LatLng(bounds.sw[0], bounds.sw[1]);

            this.fitBounds(new google.maps.LatLngBounds(sw, ne));
        },

        /**
         *  Center the map on the specified location
         *  @param  {geous.Location}    location    the location
         */
        centerOnLocation: function(location) {

            var center,
            coords = location.coordinates;

            if (!(this.locations instanceof plugin.locationMarkerCollection)) return;

            center = new google.maps.LatLng(coords.lat, coords.lng);

            this.setCenter(center);
        }
    };

    /**
     *  Create a new map
     *
     *  @constructor
     *  @param  {Object}    opts    the parameters
     */
    plugin.create = function(opts) {

        var defaults = {
            center: new google.maps.LatLng(26, 121),
            el: null,
            locations: null, // TODO: Add any initial locations and center
            on: {},
            mapTypeId: google.maps.MapTypeId.ROADMAP,
            zoom: 5
        }, options = geous.extend({}, defaults, opts);

        var mapRoot = (options.el instanceof jQuery) ? options.el.get(0) : options.el;

        var map = new google.maps.Map(mapRoot, options);

        geous.extend(map, _mapPrototype);

        /**
         *  Add markers to the map as they're added to the map's location collection
         *  @private
         *  @callback
         */
        var _onAdd = function (locationMarker, opts) {

            var coords = locationMarker.location.coordinates,
                event,
                eventHandler,
                options = geous.extend({}, (opts || {}), {
                    map: map,
                    position: new google.maps.LatLng(coords.lat, coords.lng)
                });

            locationMarker.marker = new google.maps.Marker(options);

            if (options.on) {
                for (event in options.on) {

                    eventHandler = function() {
                        var handler = options.on[event],
                            location = locationMarker.location;

                        return function() {
                            handler.call(location);
                        }
                    }();

                    google.maps.event.addListener(locationMarker.marker, event, eventHandler);
                }
            }
        };

        /**
         *  Remove markers from the map when they're removed from the map's location collection
         *  @private
         *  @callback
         */
        var _onRemove = function (locationMarker) {
            locationMarker.marker.setMap(null);
        };
    
        map.locations = new plugin.locationMarkerCollection();
        map.locations.on('add', _onAdd);
        map.locations.on('remove', _onRemove);

        var i;

        if (options.locations instanceof Array) {
            for (i = 0; i < options.locations.length; i++) {
                map.locations.add(options.locations[i]);
            }

            if (i == 1) map.centerOnLocation(options.locations[0]);
            if (i > 1) map.fitToLocations(map.locations);
        }

        return map;
    }

})(window.geous);
