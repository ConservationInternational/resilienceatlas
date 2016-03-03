(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Slider = Backbone.View.extend({

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.cacheVars();
      this.setUp();
    },

    model: new (Backbone.Model.extend({
      defaults: {
        index: 0
      }
    })),

    events: {
      'click .m-slider__pagination' : 'setPagCurrent',
      'click .m-slider__navigation' : 'setNavCurrent'
    },

    setUp: function() {
      $('.m-slider__itemlist').slick({
        centerMode: true,
        centerPadding: '120px',
        arrows: true,
        slidesToShow: 1
      });

      // this.handleNav();
    },

    cacheVars: function() {
      this.sliderLength = $('.m-slider__item').length;
    },

  });

})(this);
