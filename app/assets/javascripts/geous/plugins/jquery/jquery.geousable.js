/**
 *	jquery.geousable.js
 *
 *	v1.0
 *
 *	Provides jQuery interface for Geous.js
 *	github.com/rjz/geous.js
 *
 *	@author	RJ Zaworski (@rjzaworski)
 *	@license JSON
 */
;
(function ($) {

	'use strict';

	var geousable = function($this, opts) {

		var defaults = {

			errorHandler: function() {},

			// convenience: supply a pattern to use for any null
			// mappings, using `{%}` as a wildcard. For instance, 
			// `[name="location[{%}]"` will map to 
			// `[name="location[raw_address]"]`, etc, etc.
			defaultMapPattern: '.{%}',

			// Override the default map to match Geous result fields 
			// to the CSS selectors in use on your form
			map: {
				'raw_address': null,
				'address'    : null,
				'city'       : null,
				'state'      : null,
				'lat'        : null,
				'lng'        : null
			},

			// Callback to call when a lookup fails to populate a 
			// field on setLocation
			onFieldError: null,

			// Callback to call when a lookup successfully populates 
			// a field on setLocation
			onFieldSuccess: null,
			
			// Overwrite user-filled fields on setLocation?
			overwrite: false
		}

		var	_val = function(val) {

			var args = [],
				result;

			if (this.length) {

				if (val) {
					args.push(val);
				}

				this.each(function () {

					var $this = $(this),
						method = $this.is(':input') ? 'val' : 'text';

					result = $this[method].apply($this, args);
				});
			}

			return result;
		};

		var options = $.extend({}, defaults, opts);

		// apply defaultMapPattern to any null mappings
		$.each(options.map, function (attr, selector) {
			if (selector === null) {
				options.map[attr] = options.defaultMapPattern.replace('{%}', attr);
			}
		});

		this.options = options;

		// run a `geous.geocode` request on the any matched elements
		//
		// `opts` may include any valid option for `geous.geocode`
		//
		this.geocode = function (opts) {

			var location = this.getLocation();

			if (this.options.errorHandler && !opts.error) {
				opts.error = this.options.errorHandler;
			}

			if (location.toAddress() != '') {
				geous.geocode(location, opts);
			}
		};

		// Retrieve a selector containing all fields matched by the
		// current field map
		//
		// @return {jQuery}
		//
		this.getMappedFields = function () {

			var $fields = $();

			$.each(this.options.map, function(attr, selector) {
				$fields = $fields.add(selector, $this);
			});
			return $fields;
		};

		// retrieve a `geous.Location` object from the DOM
		//
		//	@return	{geous.Location}
		//
		this.getLocation = function () {

			var	coordinates,
				hash = {},
				location;

			$.each(this.options.map, function(attr, selector) {

				var $field = $(selector, $this),
					method = $field.is(':input') ? 'val' : 'text';

				if ($field.length) {
					hash[attr] = $field[method]();
				}
			});

			location = new geous.Location(hash);

			location.setCoordinates(hash);

			return location;
		};

		// map a `geous.Location` object onto the DOM
		//
		// @param	{Object}	location	geous.Location or valid constructor arguments
		// @param	{Object=}	ops		hash of options
		//
		this.setLocation = function (location, opts) {

			var self = this;

			var defaults = {
					only: []
				};

			var hash = new geous.Location(location);

			var options = $.extend(defaults, opts);

			$.each(this.options.map, function(attr, selector) {

				var $field = $(selector, $this),
					val = hash[attr],
					method = $field.is(':input') ? 'val' : 'text';

				// skip any fields listed
				if (defaults.only.length && options.only.indexOf(attr) == -1) {
					return;
				}

				if (attr == 'lat' || attr == 'lng') {
					val = hash.coordinates[attr];
				}

				if ((self.options.overwrite) || ($field[method]() == '')) {
					$field[method](val);
				}

				if (val == '') {
					if (typeof(self.options.onFieldError) == 'function') {
						self.options.onFieldError.call(self, $field);
					}
				} else {
					if (typeof(self.options.onFieldSuccess) == 'function') {
						self.options.onFieldSuccess.call(self, $field, val);
					}
				}
			});
		};
	};

	$.fn.geousable = function (param) {

		var args = Array.prototype.slice.call(arguments, 1),
			result;

		$(this).each(function() {

			var $this = $(this),
				data = $this.data('geous');

			if (!data) {
				data = new geousable($this, param);
				$this.data('geous', data);
			}

			if (data[param]) {
				result = data[param].apply(data, args);
				if (typeof result != 'undefined') return false;
			}
		});

		return (typeof result != 'undefined') ? result : $(this);
	};	

})(window.jQuery);
