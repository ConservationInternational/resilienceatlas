(function(root) {

  'use strict';

  root.app = root.app || {};

  root.app.Router = Backbone.Router.extend({

    defaults: {
      decoded: false, // "true" to save params in base64 string like '?config='
      update: true // If "true" It will show params in url when params change
    },

    routes: {
      '': 'welcome',
      'map': 'map',
      'embed/map': 'map',
      'about': 'about',
      'journeys/:id': 'journeys',
      'embed/journeys': 'journeys',
    },

    ParamsModel: Backbone.Model.extend({}),

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.params = new this.ParamsModel(); // This object save the URL params

      this._checkJourneyMap();
      this.setListeners();
    },

    /**
     * Add class to body if journey map version
     */
    _checkJourneyMap: function() {
      var params = this._unserializeParams();

      if (params.journeyMap) {
        $('body').addClass('is-journey-map');
      }
    },

    setListeners: function() {
      this.on('route:map', this.updateParams, this);
      this.on('route:journeys', this.updateParams, this);

      if (this.options.update) {
        this.listenTo(this.params, 'change', this.updateUrl);
      }
    },

    /**
     * Set params and update model
     * @param {String} name
     * @param {String|Object|Array} value
     * @param {Array[String]} keys
     */
    setParams: function(name, value, keys) {
      if (typeof value === 'string' || typeof value === 'number') {
        this.params.set(name, value);
      } else if (typeof value === 'object' && !_.isArray(value)) {
        if (keys && _.isArray(keys)) {
          var params = _.pick(value, 'id', 'opacity', 'order');
          this.params.set(name, JSON.stringify(params));
        } else {
          this.params.set(name, JSON.stringify(value));
        }
      } else if (typeof value === 'object' && _.isArray(value)) {
        if (keys && _.isArray(keys)) {
          var params = _.map(value, function(v) {
            return _.pick(v, keys);
          });
          this.params.set(name, JSON.stringify(params));
        } else {
          this.params.set(name, JSON.stringify(value));
        }
      }
    },

    /**
     * Change url with params
     */
    updateUrl: function() {
      var url = location.pathname.slice(1);
      if (this.options.decoded) {
        url = url + '?config=' + this._encodeParams();
      } else {
        url = url + '?' + this._serializeParams();
      }
      if (!this.params.attributes.journeyMap) {
        this.navigate(url, { trigger: false });
      }
    },

    /**
     * This method will update this.params object when URL change
     * @param  {String} routeName
     * @param  {Array} params
     */
    updateParams: function(params, routeName) {
      if (this.options.decoded && params[0]) {
        try {
          params = this._decodeParams(params[0]);
        } catch(err) {
          console.error('Invalid params. ' + err);
          params = null;
          return this.navigate('map');
        }
        this.params.clear({ silent: true }).set({ config: params });
      } else {
        var p = this._unserializeParams();
        this.params.clear({ silent: true }).set(this._unserializeParams());
      }
    },

    /**
     * Tranform base64 string to object
     * @return {Object}
     */
    _decodeParams: function() {
      var config = decodeURIComponent(location.search.slice(1)).split('config=');
      return JSON.parse(atob(config[1] || null));
    },

    /**
     * Tranform object to base64 string
     * @param  {String} paramString
     * @return {Object}
     */
    _encodeParams: function() {
      return btoa(JSON.stringify(this.params.attributes.config));
    },

    /**
     * Transform URL string params to object
     * @return {Object}
     */
    _unserializeParams: function() {
      var params = {};
      if (location.search.length) {
        var paramsArr = decodeURIComponent(location.search.slice(1)).split('&'),
          temp = [];
        for (var p = paramsArr.length; p--;) {
          temp = paramsArr[p].split('=');
          if (temp[1] && !_.isNaN(Number(temp[1]))) {
            params[temp[0]] = Number(temp[1]);
          } else if (temp[1]) {
            params[temp[0]] = temp[1];
          }
        }
      }
      return params;
    },

    /**
     * Transform object params to URL string
     * @return {String}
     */
    _serializeParams: function() {
      return this.params ? $.param(this.params.attributes) : null;
    }

  });

})(this);
