(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Search = Backbone.Collection.extend({

    url: 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql',

    parse: function(data) {
      return data.rows;
    },

    getData: function() {
      var self = this;
      var fetchOptions;
      var tableName = this._getTableName();
      var query = 'SELECT initcap(s_name) as name, bbox as bbox, iso3 as iso FROM ' + tableName;

      fetchOptions = {
        dataType: 'json',
        data: {
          q: query,
          format: 'json'
        }
      };

      return this.fetch(fetchOptions);
    },

    _getTableName: function() {
      var name = 'grpcountries_250k_polygon';
      var isSubdomain = window.isSubdomain;

      if (isSubdomain === 'indicators') {
        name = 'vs_countries';
      }
      return name;
    }
  });

})(this);
