define(['backbone'], function(Backbone) {

  'use strict';

  var TimelineModel = Backbone.Model.extend({

    url: 'http://cigrp.cartodb.com/api/v2/sql',

    defaults: {
      step: '',
      startDate: '',
      endDate: ''
    },

    parse: function(data) {
      var res = data.rows.length > 0 ? data.rows[0] : null;
      var parseData;

      if(res) {
        parseData = {
          startDate: res.min,
          endDate: res.max,
          step: res.step
        };
      } else {
        parseData = {};
      }

      return parseData;
    },

    getData: function(sql) {
      var self = this;
      var query, fetchOptions;
      var select = 'min(year) as min, max(year) as max, count(year) as step';

      query = sql.replace(/\*/g, select);

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

  return TimelineModel;
});
