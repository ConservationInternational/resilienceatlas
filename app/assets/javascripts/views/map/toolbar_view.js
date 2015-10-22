(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Toolbar = Backbone.View.extend({

    el: '#toolbarView',

    events: {
      'click .btn-share' : '_share',
      'click .btn-analyze' : '_analyze'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
    },

    _share: function() {
      Backbone.Events.trigger('share:show');
    },

    _analyze: function() {
      var analyze = new root.app.View.analysisSelectors();
    }

  });

})(this);
