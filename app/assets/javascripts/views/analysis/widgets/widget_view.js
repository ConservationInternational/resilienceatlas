(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Widget = Backbone.View.extend({

    defaults: {

    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.render();
    },

    render: function() {
    	console.log('render');
    }

  });

})(this);