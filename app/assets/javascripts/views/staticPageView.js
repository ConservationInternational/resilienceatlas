(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.StaticPageView = Backbone.View.extend({

    el: 'body',

    events: {},

    templates: {},

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this._cacheVars();
      this._setListeners();
    },

    _cacheVars: function() {
      this.$anchors = this.$('a.link');
    },

    _setListeners: function() {
      this.$anchors.on('click', this._scrollToSection);
    },

    _scrollToSection: function(e) {
      e && e.preventDefault();

      var $anchor = $(e.currentTarget).attr('href');
      var targetPosition = $($anchor).offset().top;

      $('html, body').animate({
        scrollTop: targetPosition - 20
      }, 300);
    }

  });

})(this);
