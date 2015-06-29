define([
  'underscore',
  'backbone',
  'handlebars',
  'text!templates/helpers/share_window_tpl.handlebars'
], function(_, Backbone, Handlebars, tpl) {

  'use strict';

  var ShareWindow = Backbone.View.extend({

    el: 'body',

    events: function() {
      if (window.ontouchstart) {
        return  {
          'touchstart .btn-close-modal': 'close',
          'touchstart .modal-background': 'close',
          'click .btn-copy--url': 'copyUrl'
        };
      }
      return {
        'click .btn-close-modal': 'close',
        'click .modal-background': 'close',
        'click .btn-copy--url': 'copyUrl'
      };
    },

    template: Handlebars.compile(tpl),

    initialize: function() {
      // Get embed url
      var url = window.location.origin;
      // Get embed modal template
      var html = this.template({
        iframeCode: '<iframe src="' + url + '"></iframe>',
        url: url
      });

      this.$el.append(html);
    },

    close: function() {
      $('.m-modal-window').remove();
      this.toogleState();
    },

    toogleState: function() {
      this.$el.toggleClass('has-no-scroll');
      $('html').toggleClass('has-no-scroll');
    }

  });

  return ShareWindow;

});
