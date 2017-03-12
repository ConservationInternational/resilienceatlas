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
      var query = 'SELECT name_engli as name, bbox as bbox, iso as iso FROM ' + tableName;

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
      var name = "gadm28_adm0 where not iso ='TWN'";
      var isSubdomain = window.isSubdomain;

      if (isSubdomain === 'indicators') {
        name = "gadm28_adm0 where iso in ('KEN', 'UGA', 'GHA', 'RWA', 'TZA')";
      }
      return name;
    }
  });

})(this);
