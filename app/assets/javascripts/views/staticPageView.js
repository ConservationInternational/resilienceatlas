(function(root) {

  'use strict';

  root.app = root.app || {};

  root.app.StaticPageView = Backbone.Router.extend({


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.setListeners();
    },

    setListeners: function() {
    }

    
  });

})(this);
