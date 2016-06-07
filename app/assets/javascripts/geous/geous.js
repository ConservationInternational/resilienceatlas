/*
 *  Geous.js: Javascript geolocation made easy.
 *
 *	rjz.github.com/geous.js
 *
 *	@author	RJ Zaworski (@rjzaworski)
 *	@license JSON
 */
;
(function (undefined) {

var geous = new function () {

    'use strict';

    var /**
         *  Default options. Any key/value described here may be overwritten by 
         *  overwriting parameters in `geous.options`
         *
         *  @private
         */
        _defaults = {

            /**
             *  Should the geocoder cache results? Setting this option will not
             *  force results to be cached, but will at least make the cache
             *  available.
             */
            useCache: false,

            /**
             *  localStorage adapter. Override this as needed to provide 
             *  persistence with databases, socket connections, etc.
             */
            cacheAdapter: {

                store:localStorage,

                get: function (key) {
                    try {
                        return JSON.parse(this.store[key]);
                    } catch(e) {};
                    return undefined;
                },
                set: function (key, value) {
                    try {
                        this.store[key] = JSON.stringify(value);
                    } catch(e) {};
                }
            },

            /**
             *  Should geocoder results be persisted using `cacheAdapter`?
             */
            cachePersist: false,

            /**
             *  Prefix to use for cached values (e.g., `window.location`)
             */
            cachePrefix: '',

            /**
             *  Geocoding service to use
             */
            geocoder: 'google'
        },

        /**
         *  Convert degrees to radians
         *  @private
         *  @param  {Number}    degrees the angle in degrees
         *  @return {Number}    the angle in radians
         */
        _deg2rad = function (degrees) {
            return degrees * Math.PI / 180;
        },
        
        
        /**
         *  Shallow copies object properties onto the first object passed
         *
         *  @param  {Object}    obj1    The destination object
         *  @param  {Object}    obj2    Additional objects to copy
         *  @private
         */
        _extend = function () {

            var i = 0, key, obj,
                result = arguments[0];

            while (obj = arguments[i++]) {
                if (obj instanceof Object) {
                    for(key in obj) {
                        result[key] = obj[key];
                    }
                }
            }

            return result;
        },

        /**
         *  a convenient default for callbacks
         *  @private
         */
        _nop = function() { /* nothing to see here */ };

    /**
     *  Expose `_extend` method
     */
    this.extend = _extend;

    /**
     *  Basic event handling
     */
    this.Events = {

        /**
         *  A hash of event listeners
         *  @type   {Object}
         */
        listeners: {},

        /**
         *  Bind a callback to an event
         *  @param  {String}    event   the event to listen for
         *  @param  {Function}  callback    the callback to execute on `event`
         */
        on: function (event, callback) {
            var evt = this.listeners[event] || [];
            evt.push(callback);
            this.listeners[event] = evt;
        },

        /**
         *  Remove a callback for an event
         *  @param  {String}    event   the event to listen for
         *  @param  {Function}  callback    the callback to execute on `event`
         */
        off: function (event, callback) {
            var i = 0, 
                l;
            while (l = this.listeners[event][i++]) {
                if (l == callback) {
                    this.listeners[event].splice(i-1, 1);
                }
            }
        },

        /**
         *  Trigger an event, firing any callbacks bound by `on`. Any additional
         *  parameters passed will be forwarded to each callback function
         *
         *  @param  {String}    event   the event to listen for
         */
        trigger: function (event) {

            var args = [].splice.call(arguments, 1),
                callback,
                i = 0;

            if (!this.listeners[event]) return;

            while (callback = this.listeners[event][i++]) {
                callback.apply(this, args);
            }
        }
    };

    /**
     *  Namespace for geocoding service providers
     *  @namespace
     */
    this.geocoders = function () {

        var _services = {};

        return function(name) {
            if (!_services.hasOwnProperty(name)) {
                _services[name] = _extend({}, geous.Events); 
            }
            return _services[name];
        }
    }();

    /**
     *  Describes the geocoder cache
     *
     *  Options include:
     *
     *  - `persist`       : whether the cache should persist through
     *                      the supplied `storageAdapter`
     *  - `prefix`        : an arbitrary prefix (e.g., `window.location`)
     *                      used to identify cached results
     *  - `storageAdapter`: the persistence layer to use for caching
     *
     *  @constructor
     *  @param  {Object=}   opts    caching options
     */
    this.HashStore = function (opts) {

        var 
            // A list of cached req/res pairs
            _cached = {},

            // Default settings
            _options = {
                persist: false,
                prefix: '',
                storageAdapter: null
            },
    
            // Should the cache persist between page loads?
            _persist = false,

            // Convert an arbitrary request to a unique string
            _serialize = function(key) {
                return JSON.stringify(key);
            };

        _extend(_options, opts);

        /**
         *  Retrieve the response to a cached request
         *
         *  @param  {Object}    req the request to look up
         *  @return {Object}    the response to the request or `null` if unavailable
         */
        this.get = function (req) {
            req = _serialize(req);
            if (_cached[req] instanceof Object) {
                return _cached[req].item;
            }
            return null;
        };

        /**
         *  Set a cache request/response pair
         *
         *  @param  {Object}    req the request that generated the response
         *  @param  {Object}    res the response retrieved
         */
        this.set = function (req, res) {
            
            req = _serialize(req);

            _cached[req] = {
                date: new Date(),
                item: res
            };

            if (_persist && _options.storageAdapter) {
                // store to persistence layer
                _options.storageAdapter.set('geous', _cached);
            }
        };

        /**
         *  Store the cache using an arbitrary persistence layer (by default
         *  using a localStorage adapter)
         */
        this.persist = function () {

            if (!(_options.storageAdapter instanceof Object)) {
                throw('geous.Cache.persist failed: no storageAdapter available');
            }

            if (!_persist) {
                // retrieve from persistence layer?
                _cached = _extend({}, _options.storageAdapter.get('geous'), _cached);
                _options.storageAdapter.set('geous', _cached)
            }

            _persist = true;
        };

        if (_options.persist) {
            this.persist();
        }
    };

    /**
     *  Locations are the basic unit of geous data, containing:
     *
     *   * a lat/lng coordinate pair (`location.coordinates`)
     *   * textual address compontents (`location.address`, etc)
     *   * helper utilities for converting between them
     *
     *  The constructor accepts a variety of formats, including:
     *  
     *      new geous.Location(new geous.Location());
     *      new geous.Location('123 abc st, akron, ohio');
     *      new geous.Location(48.3689, -99.9962);
     *      new geous.Location([48.3689, -99.9962]);
     *      new geous.Location(['123 abc st', 'akron', 'ohio']);
     *      new geous.Location({lat: 48.3689, lng: -99.9962});
     *      new geous.Location({city: 'akron', state: 'ohio'});
     *
     *  `geous.Location` is a convenience object. It's up to the application developer 
     *  to ensure that the coordinates and address of any given location are congruous 
     *  before geocoding is performed
     *
     *  @extends {geous.Events}
     *  @param  {Object|Array|Number|String}    location    A representation of a location
     */
    this.Location = (function () {

        var defaults = {
                coordinates: {
                    lat: null,
                    lng: null
                },
                name: '',
                raw_address: '',
                city: '',
                country: '',
                state: '',
                address: '',
                zipcode: '',
            };

        /**
         *  @constructor
         *  @param  {geous.Location|String|Number|Array}  location    a location
         */
        function Location (location) {

            _extend(this, geous.Events, defaults);

            if (location !== undefined) {

                if (location instanceof geous.Location) {
                    // copy the location
                    _extend(this, location);
                } else if (typeof location == 'string') {
                    // guess: loc follows '123 abc st akron ohio'
                    this.setAddress(location);
                } else if (typeof location == 'number' && typeof arguments[1] == 'number') {
                    // guess: loc follows (lat, lng)
                    this.setCoordinates({
                        lat: location, 
                        lng: arguments[1]
                    });
                } else if (location instanceof Array) {
                    if (typeof location[0] == 'string') {
                        // guess: loc follows ['addressComponent1', ...]
                        this.setAddress(location);
                    } else if (location.length == 2) {
                        // guess: loc follows [lat, lng]
                        this.setCoordinates({
                            lat: location[0], 
                            lng: location[1]
                        });
                    }
                } else if (location instanceof Object) {
                    location = _extend({}, location);
                    if (location.lat && location.lng) {
                        // guess: loc follows {lat: ..., lng: ... }
                        this.setCoordinates(location);
                        delete location.lat, location.lng;
                    }
                    // guess: loc follows {city: ..., state: ... }
                    this.setAddress(location);
                } else {
                    throw('geous.Location: unrecognized address format');
                }
            }

            return this;
        };

        /**
         *  Set the address of this location
         *  
         *  `address` parameter may follow any of the following formats:
         *
         *  - this.setAddress('123 abc st, akron, ohio');
         *  - this.setAddress(['123 abc st', 'akron', 'ohio']);
         *  - this.setAddress({city: 'akron', state: 'ohio'});
         *
         *  @param  {Object|Array|String}   address a representation of the ad�dress
         */
        Location.prototype.setAddress = function (address) {

            var key;
            if (address instanceof Array) {
                this.raw_address = address.join(' ');
            } else if (address instanceof Object) {
                for (key in defaults) {
                    if (address[key]) {
                        this[key] = address[key];
                    }
                }
            } else if (typeof address == 'string') {
                this.raw_address = address;
            }
        };

        /**
         *  Sets the coordinates of this location
         *
         *  Input may follow a variety of formats:
         *
         *  - this.setCoordinates(48.3689, -99.9962);
         *  - this.setCoordinates([48.3689, -99.9962]);
         *  - this.setCoordinates({lat: 48.3689, lng: -99.9962});
         *
         *  @param  {Array|Object|Number}   lat
         *  @param  {Number=}   lng
         */
        Location.prototype.setCoordinates = function (lat, lng) {

            if (lat instanceof Array) {
                lng = lat[1];
                lat = lat[0];
            } else if (lat instanceof Object) {
                lng = lat.lng;
                lat = lat.lat;
            }

            this.coordinates = {
                lat: lat,
                lng: lng
            };
        };

        /**
         *  Returns a textual representation of this location
         *
         *  Return format:
         *      '123 Main st., Anywhere, USA'
         *
         *  @return {String}
         */
        Location.prototype.toAddress = function () {

            var address = [this.address, this.city, this.state, this.zipcode, this.country].join(' ');

            if (address.trim() != '') {
                return address;
            } else if (this.raw_address != '') {
                return this.raw_address;
            }
        };

        return Location;
    })();

    /**
     *  @namespace
     */
    this.calculate = {

        /**
         *  Compute initial bearing from one location to another
         *
         *  @param  {geous.Location}    p1  The location from
         *  @param  {geous.Location}    p2  The location to
         *  @return {Number}    initial bearing in degrees
         */
        bearing: function (p1, p2) {

            var angle,
                p1 = p1.coordinates,
                p2 = p2.coordinates,
                d_lng = _deg2rad(p2.lng-p1.lng),
                lat1 = _deg2rad(p1.lat),
                lat2 = _deg2rad(p2.lat),
                x = Math.cos(lat1)*Math.sin(lat2) - Math.sin(lat1)*Math.cos(lat2) * Math.cos(d_lng),
                y = Math.sin(d_lng) * Math.cos(lat2)

            angle = (Math.atan2(y, x) * 180 / Math.PI);

            if (angle < 0) {
                angle += 360;
            }

            return angle % 360;

        },

        /**
         *  Compute distance between two points using Haversine Formula
         *
         *  @see    http://en.wikipedia.org/wiki/Haversine_formula
         *
         *  @param  {geous.Location}    p1  The location from
         *  @param  {geous.Location}    p2  The location to
         *  @return {Number}    distance in km
         */
        distanceBetween: function (p1, p2) {

            var radius = {
                'km': 6371,
                'mi': 3959 
            };

            p1 = p1.coordinates;
            p2 = p2.coordinates;

            var d_lat = _deg2rad(p2.lat-p1.lat),
                d_lng = _deg2rad(p2.lng-p1.lng),
                lat1 = _deg2rad(p1.lat),
                lat2 = _deg2rad(p2.lat),
                a = Math.sin(d_lat/2) * Math.sin(d_lat/2) + Math.sin(d_lng/2) * Math.sin(d_lng/2) * Math.cos(p1.lat) * Math.cos(p2.lat),
                c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 

            return radius.km * c;
        }
    };

    /**
     *  Initiate a geocoding request
     *
     *  Options include:
     *
     *  - `reverse` a flag indicating that a reverse lookup should be used to find
     *              the address at a lat/lng pair
     *  - `success` a callback function to receive the new `geous.Location` populated
     *              by a successful geocoding request
     *  - `error` a callback function to receive an error status when a request fails
     *
     *  @param  {geous.Location}    location    the location to code up
     *  @param  {Object=}   opts    options
     */
    this.geocode = function (location, opts) {

        var defaults = {
            reverse: false,
            success: _nop,
            error: _nop
        };

        var options = _extend({}, defaults, opts);

        var provider = this.options.geocoder,
            service = this.geocoders(provider);

        if (!service.geocode) {
            throw('geous.geocode: provider ' + provider + ' does not support geocoding');
        }

        if (!(location instanceof geous.Location)) {
            location = new geous.Location(location);
        }

        service.geocode(location, options);
    };

    /**
     *  Get the user's current location
     *
     *  Options include:
     *
     *  - `success` a callback function to receive the user's location if it can be
     *              retrieved successfully
     *  - `error`   a callback function to receive an error status when a request fails
     *  - `geocode` if `true`, location will be geocoded before success callback is
     *              called
     *
     *  @param  {Object=}   opts    options 
     */
    this.getUserLocation = function (opts) {

        var defaults = {
            success: _nop,
            error: _nop,
            geocode: false
        };

        var options = _extend({}, defaults, opts);

        // convert a successful response into a geous.Location and call the
        // user-specified `success` function:
        var _successHandler = function(position) {
            var coords = position.coords,
                location = new geous.Location(coords.latitude, coords.longitude);

            if (options.geocode) {
                // pass location+callbacks through to geocode()
                geous.geocode(location, {
                    reverse: true,
                    success: options.success,
                    error: options.error
                });
            } else {
                options.success(location);
            }
        }

        // check to make sure the browser supports the geolocation API:
        if (!navigator.geolocation) {
            return options.error('Browser does not support geolocation');
        }

        navigator.geolocation.getCurrentPosition(_successHandler, options.error);
    };

    this.configure = function (opts) {

        _extend(this.options, opts);

        if (this.options.useCache) {
            // set up cache
            this.cache = new this.HashStore({
                persist        : this.options.cachePersist,
                prefix         : this.options.cachePrefix,
                storageAdapter : this.options.cacheAdapter
            });
        }
    };

    // set up  event handling and defaults
    _extend(this, this.Events, { options: _defaults });
};

// expose geous to global namespace
this.geous = geous;

})();


(function (service) {

	'use strict';

	var _mappings = {
		'street_number'               : '_streetno',
		'route'                       : '_route',
		'locality'                    : 'city',
		'administrative_area_level_1' : 'state',
		'postal_code'                 : 'zipcode'
	};

	/**
	 *  Patch geous.Location to add toLatLng()
	 *  @return {google.maps.LatLng}
	 */
	geous.Location.prototype.toLatLng = function () {
		 var coords = this.coordinates;
		 return new google.maps.LatLng(coords.lat, coords.lng);
	};

	/**
	 *	Extract a named address component from a geocoder result
	 *
	 *	@private
	 *	@param	{String}	key	the key of the component to extract
	 *	@param	{Object}	result	the geocoder result to search
	 *	@return	{String}	the value of the key, if available, or an empty string
	 */
	var _mapComponents = function(location, response) {
	
		var c, components = response.address_components,
			i = 0,
			j, type,
			result;

		while(c = components[i++]) {
			j = 0;
			while (type = c.types[j++]) {
				if ((type = _mappings[type]) && c.long_name) {
					location[type] = c.long_name;
				}
			}
		}

		if (location._streetno && location._route) {
			location.address = location._streetno + ' ' + location._route;
			delete location._streetno;
			delete location._route;
		}
	};

	/**
	 *	Converts a Google Maps geocoder result into a geous Location
	 *
	 *	@private
	 *	@param	{google.maps.GeocoderResult}	response
	 *	@return	{geous.Location}
	 */
	var _getLocation = function(response) {
		var location = new geous.Location();
		
		location.coordinates = {
			lat: response.geometry.location.lat(),
			lng: response.geometry.location.lng()
		};

		_mapComponents(location, response);
		return location;
	};

	/**
	 *	Use a geocoder to populate the location in question
	 *
	 *	The `opts` parameter focuses
	 *
	 *	@param	{geous.Location}	originalLocation	guess.
	 *	@param	{Object}	opts	geocoder options
	 */
	service.geocode = function(originalLocation, opts) {

		var coords,
			gc = new google.maps.Geocoder(),
			request;

        if (typeof(google) == 'undefined') {
            throw('Please provide the Google Maps API before attempting to geocode with Google');
        }

		if (opts.reverse) {
			// lat, lng
			coords = originalLocation.coordinates
			request = { location : new google.maps.LatLng(coords.lat, coords.lng) }
		} else {

			// 123 Main st., Anywhere, USA
			request = { address : originalLocation.toAddress() }
		}

		gc.geocode(request, function(result, status) {

			var location;

			if( status === google.maps.GeocoderStatus.OK ) {
				result = _getLocation(result[0]);
				service.trigger('success', result);
				opts.success(result);
			} else {
				service.trigger('error', status, result);
				opts.error(status, result);
			}
		});
	}

})(geous.geocoders('google'));
