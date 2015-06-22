define([
  'backbone',
  'underscore',
  'handlebars',
  'lib/utils',
  'text!templates/map/custom_info_window_tpl.handlebars'
], function(Backbone, _, Handlebars, utils, TPL) {

  'use strict';

  var CustomInfoWindowView = Backbone.View.extend({

    events: {
    },

    template: Handlebars.compile(TPL),

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.render();
      this.setListeners();
    },

    setListeners: function() {
      Backbone.Events.on('timeline:info-window', this.setPosition, this);

      $(window).on('resize', _.bind(this.setPosition, this));
    },

    render: function() {
      this.$el.html(this.template({}));

      this.setInitialValues();
    },

    setInitialValues: function() {
      var $arrow = this.$el.find('.custom-info-window-arrow');
      var arrowLeft = parseFloat($arrow.css('left'), 10);

      this.initialArrowLeft = arrowLeft;
    },

    show: function() {
      var $body = $('body');
      if(!$body.hasClass('custom-info-window-visible')) {
        $body.addClass('custom-info-window-visible');
        $body.on('click', this.hide);;
      }
    },

    hide: function(e) {
      var $body = $('body');
      var target = e ? e.target : null;
      var $parent = $(target).parents('.m-custom-info-window');
      var isOwnContainer = $parent.is('.m-custom-info-window');

      if($body.hasClass('custom-info-window-visible') && !isOwnContainer) {
        $body.removeClass('custom-info-window-visible');
        $body.off('click', this.hide);
        Backbone.Events.trigger('custom-info-window:closed');
      }
    },

    set: function(data, position) {
      this.position = position;
      this.setData(data);
      this.show();
      this.setPosition();
    },

    setData: function(data) {
      this.$el.html(this.template(data));
    },

    setPosition: function() {
     var $body = $('body');
      if($body.hasClass('custom-info-window-visible')) {
        var position = this.position;
        var $elem = position.element;
        var elemPos = $elem.offset();
        var left = elemPos.left + ($elem.width() / 2)

        var $container = this.$el;
        var $arrow = this.$el.find('.custom-info-window-arrow');
        var leftPos = left;
        var topPos = position.top;
        var containerWidth = $container.width();
        var pageWidth = $(document).width();
        var leftMargin = leftPos - (containerWidth / 2);
        var rightMargin = leftPos + (containerWidth / 2);

        if(rightMargin > pageWidth) {
          this.$el.css({left: 'auto', right: 0, bottom: topPos});
          this.setArrowPosition(leftPos);
        } else if(leftMargin < 0) {
          this.$el.css({left : 0, right: 'auto', bottom: topPos});
          this.setArrowPosition(leftPos);
        } else {
          this.$el.css({left: leftMargin, right: 'auto', bottom: topPos});
          $arrow.css({left: this.initialArrowLeft});
        }
      }
    },

    setArrowPosition: function(leftPos) {
      var $arrow = this.$el.find('.custom-info-window-arrow');
      var arrowBorder = $arrow.css('border-width');
      var arrowWidth = parseInt(arrowBorder.split('px')[0], 10);
      var arrowLeft = Math.round(parseFloat($arrow.css('left'), 10));
      var arrowLeftOffset = $arrow.offset().left;
      var newArrowPosition = (leftPos - arrowLeftOffset) + (arrowLeft-arrowWidth) + 3;

      $arrow.css({left: newArrowPosition});
    }

  });

  return CustomInfoWindowView;

});
