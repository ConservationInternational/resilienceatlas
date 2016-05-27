(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Model = root.app.Model || {};

  root.app.Model.Subdomain = Backbone.Model.extend({

    url: '/api/site',

  });

})(this);
