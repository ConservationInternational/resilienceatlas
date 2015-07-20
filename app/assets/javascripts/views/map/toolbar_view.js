define([
  'backbone',
  'views/helpers/share_window_view'
], function(Backbone, ShareWindow) {

  'use strict';

  var ToolbarView = Backbone.View.extend({

    initialize: function() {
      $('#btn-share-map').on('click', this.openShareWindow);
    },

    openShareWindow: function() {
      new ShareWindow({ el: 'body' });
    }
  });

  return ToolbarView;
});
