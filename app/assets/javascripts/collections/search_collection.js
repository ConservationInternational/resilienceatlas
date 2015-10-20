(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  root.app.Collection.Search = Backbone.Collection.extend({

    // url: 'https://grp.global.ssl.fastly.net/user/grp/api/v1/sql',

    url: 'data/countries.json', 

    parse: function(data) {
      return data.rows;
    },
    
    getData: function() {
      var self = this;
      var fetchOptions;
      var query = 'SELECT initcap(s_name) as name, bbox, iso3 as iso FROM grpcountries_250k_polygon';

      fetchOptions = {
        dataType: 'json',
        data: {
          q: query,
          format: 'json'
        }
      };

      return this.fetch(fetchOptions);
    }
  });

})(this);