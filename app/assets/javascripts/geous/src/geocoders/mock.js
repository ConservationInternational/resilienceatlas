(function (service) {

	'use strict';

	/**
	 *	Provide a mock geocoder for testing
	 *
	 *	@param	{geous.Location}	originalLocation	guess.
	 *	@param	{Object}	opts	geocoder options
	 */
	service.geocode = function (originalLocation, opts) {

		if (opts.response.type == 'error') {
			service.trigger('error', opts.response.status, opts.response.result);
			opts.error(status, result);
		} else {
			service.trigger('success', opts.response.status, opts.response.result);
			opts.success(result);
		}
	}


})(geous.geocoders('mock'));
