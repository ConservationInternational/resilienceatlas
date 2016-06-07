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
