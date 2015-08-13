(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Slider = Backbone.View.extend({

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.setUp();
      this.cacheVars();
      this.setListeners();
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

    setListeners: function() {
      this.listenTo(this.model,'change:index', this.changeCurrent);
    },

    setUp: function() {
      $('.m-slider__itemlist').slick({
        infinite: true,
        speed: 500,
        // autoplay: true,
        autoplaySpeed: 6000,
        slide: 'li',
        adaptiveHeight: true,
        fade: true,
        cssEase: 'linear',
        pauseOnHover: false,
        arrows: false,
      });


      $('.m-slider__paginationlist').slick({
        slidesToShow: 6,
        slidesToScroll: 6,
        speed: 500,
        slide: 'li'
      });

    },

    cacheVars: function() {
      this.sliderLength = $('.m-slider__item').length;
      this.$slider__pagination = this.$el.find('.m-slider__pagination');
    },

    // slickGoTo

    setPagCurrent: function(e) {
      this.model.set('index', $(e.currentTarget).data('index'));
    },

    setNavCurrent: function(e) {
      var index = this.model.get('index');
      var direction = $(e.currentTarget).data('direction');

      switch(direction) {
        case 'left':
          (index === 0) ? index = 0 : index--;
        break;
        case 'right':
          (index === this.sliderLength - 1) ? index = this.sliderLength - 1 : index++;
        break;
      }

      this.model.set('index', index);
    },

    changeCurrent: function() {
      $('.m-slider__itemlist').slick('slickGoTo', this.model.get('index'));
      $('.m-slider__paginationlist').slick('slickGoTo', this.model.get('index'));

      this.$slider__pagination.removeClass('is-active');
      this.$slider__pagination.eq(this.model.get('index')).addClass('is-active');

    }





  });

})(this);
