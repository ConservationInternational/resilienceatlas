(function(root) {
  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.analysisModel = Backbone.View.extend({
    el: '#analysisSelectorsView',

    initialize: function() {
      this.render();
    },

    render: function() {
      this.$el.html('Analysis of the model');
    },

    /**
     * Destroy the view
     * Same as remove but without removing the node
     */
    destroy: function() {
      this.$el.html('');
    }
  });

})(this);
