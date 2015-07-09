define([
  'backbone',
  'underscore',
  'handlebars',
  'moment',
  'lib/utils',
  'models/timeline_model',
  'views/map/custom_info_window_view',
  'views/map/dashboard_timeline_view',
  'text!templates/map/timeline_tpl.handlebars'
], function(Backbone, _, Handlebars, moment, utils, TimelineModel, CustomInfoWindow, DashboardTimeline, TPL) {

  'use strict';

  var TimelineView = Backbone.View.extend({

    events: {
      'mousedown .handlerLeft': 'handlerDown',
      'mousedown .handlerRight': 'handlerDown',
      'mousemove': 'handlerMove',
      'mouseup': 'handlerUp',
      'mouseleave': 'handlerUp',
      'click .step-item-data': 'infoData'
    },

    defaults: {
      dateStart: 1970,
      dateEnd: 2031,
      groupStep: 10,
      margin: 2,
      leftHandle: '.handlerLeft',
      rightHandle: '.handlerRight',
      stepsContent: '.steps',
      stepMargin: '.step-margin',
      handlerBg: '.handler-bg'
    },

    template: Handlebars.compile(TPL),

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);
      this.map = this.options.map;
      this.model = new TimelineModel();
      this.setListeners();
      this.dashboardTimelines = [];
    },

    setListeners: function() {
      this.listenTo(this.model, {
        'change': this.dataChange
      }, this);

      Backbone.Events.on('custom-info-window:closed', this.unSelectItem, this);
      Backbone.Events.on('timeline:show', this.getData, this);
      Backbone.Events.on('timeline:hide', this.hide, this);
      Backbone.Events.on('timeline:step', this.setStepFromTimeline, this);
    },

    setDefaults: function() {
      this.dateStart = this.model.get('startDate') || this.options.dateStart;
      this.dateEnd = this.model.get('endDate') || this.options.dateEnd;
      this.margin = this.options.margin;
      this.stepNumber = this.model.get('step');

      this.leftHandle = this.options.leftHandle;
      this.rightHandle = this.options.rightHandle;

      this.steps = _.range(this.dateStart, this.dateEnd + 1);
      this.groupStep = 5;
      this.stepsLength = this.steps.length;
      this.stepsWidth = 100 / (this.stepsLength + this.margin);
      this.dragging = false;

      this.setData();

      this.customInfoWindow = new CustomInfoWindow({el: '#custom-info-window'});
    },

    getData: function(layerSlug, dashTimelineEl) {
      var self = this;
      var mapModel = this.map.model;
      this.layer = mapModel.get(layerSlug);
      var sql = this.layer.options.params.q;

      $.when(this.model.getData(sql)).then(function() {
        self.setDefaults();
        self.render(layerSlug, dashTimelineEl);
      });
    },

    setData: function() {
      var self = this;
      var stepsData = [];
      var dateStart = this.dateStart;
      var dateEnd = this.dateEnd;
      var groupStep = this.groupStep+1;
      var groupLimit =  Math.round(this.steps.length / groupStep);
      var groupsRange = _.range(dateStart, dateEnd, groupStep);
      var contSteps = 0;

      groupsRange[0] = this.dateStart;
      groupsRange[groupsRange.length - 1] = this.dateEnd;

      _.map(this.steps, function(step, i) {
        contSteps++;
        var stepData = {
          step: step,
          groupClass: ''
        };

        if(i ===7 || i === 20 || i === 22 || i === 35 || i === 45 || i === 55) { // Just for mockup
          stepData.itemData = step;
        }

        if(contSteps == groupLimit) {
          stepData.group = true;
          stepData.groupClass = 'step-group';
          contSteps = 0;
        }

        if(i === 0 || i === self.steps.length-1) {
          stepData.group = true;
          stepData.groupClass = 'step-group';
        }

        stepsData.push(stepData);
      });

      this.data = {
        steps: stepsData,
        stepWidth: this.stepsWidth
      };
    },

    dataChange: function() {
      if (this.model.hasChanged('currentStartDate') ||
        this.model.hasChanged('currentEndDate')) {
        var date = this.model.get('date');
        Backbone.Events.trigger('timeline:changed',
          this.model.get('currentStartDate'),
          this.model.get('currentEndDate'));
      }
    },

    infoData: function(e) {
      e.preventDefault();
      e.stopPropagation();

      var $elem = $(e.currentTarget);
      var itemData = $elem.data('item-data');
      // Fake data
      var data = {
        title: itemData,
        description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.' +
        'Morbi nec faucibus quam, in tincidunt arcu',
        layers: [
          {name: 'Layer 1', slug: 'slug1', active: false},
          {name: 'Layer 2', slug: 'slug2', active: false}
        ]
      }
      //
      var position = {
        element: $elem,
        top: 62
      };

      if (!$elem.hasClass('selected'))  {
        this.$('.step > .step-item-data').removeClass('selected');
        $elem.addClass('selected');
        this.customInfoWindow.set(data, position);
      } else {
        $elem.removeClass('selected');
        this.customInfoWindow.hide();
      }
    },

    unSelectItem: function() {
      this.$('.step > .step-item-data').removeClass('selected');
    },

    handlerDown: function(ev) {
      this.dragging = true;
      this.$el.addClass('dragging');
      this.draggingElement = $(ev.currentTarget).attr('data-handler');
    },

    handlerUp: function() {
      if (this.dragging) {
        this.dragging = false;
        this.draggingElement = null;
        this.$el.removeClass('dragging');

        this.model.set({
          step: this.currentStep,
          date: this.date
        });
        this.updateLayer();
      }
    },

    setHandlerElements: function() {
      this.stepsContent = this.$(this.options.stepsContent);
      this.stepMargin = this.$(this.options.stepMargin);
      this.handlerBg = this.$(this.options.handlerBg);
      this.stepMargin = this.$(this.options.stepMargin);
    },

    setStep: function(leftStep, rightStep, fromTimeline) {
      var widthMargin = this.stepsContent.width() - (this.stepMargin.width());
      var stepsWidth = widthMargin / this.stepsLength;

      if(leftStep >= 0 && leftStep !== null) {
        var leftPos = (leftStep * this.stepsWidth) + (this.stepsWidth / 2);
        var leftHandleWidth = ((this.$(this.leftHandle).width() / 2) / stepsWidth) * this.stepsWidth;
        this.$(this.leftHandle).css('left', (leftPos - leftHandleWidth) + '%');

        this.handlerLeftStep = leftStep;
      }
      if(rightStep >= 0 && rightStep !== null) {
        var rightPos = (rightStep * this.stepsWidth) + (this.stepsWidth / 2);
        var rightHandleWidth = ((this.$(this.leftHandle).width() / 2) / stepsWidth) * this.stepsWidth;

        this.$(this.rightHandle).css('left', rightPos - rightHandleWidth + '%');

        this.handlerRightStep = rightStep;
      }

      this.updateHandlerBg();
    },

    updateHandlerBg: function() {
      var widthMargin = this.stepsContent.width() - (this.stepMargin.width());
      var stepsWidth = widthMargin / this.stepsLength;

      var leftPos = (this.handlerLeftStep * this.stepsWidth) + (this.stepsWidth / 2);
      var rightPos = (this.handlerRightStep * this.stepsWidth) + (this.stepsWidth / 2);

      this.handlerBg.css('left', (leftPos) + '%');
      this.handlerBg.css('width', (rightPos - leftPos) + '%');

      this.updateTimelineData();
    },

    handlerMove: function(e) {
      if (this.dragging) {
        var $stepsContent = this.$('.steps');
        var $stepMargin = this.$('.step-margin');

        var x = e.clientX || e.pageX
        var widthMargin = $stepsContent.width() - ($stepMargin.width() * 2);
        var stepsWidth = widthMargin / this.stepsLength;
        var currentStep = Math.round(x / stepsWidth) - 1;

        if (currentStep > 0 && currentStep <= this.stepsLength) {
          if(this.draggingElement === 'handlerLeft' && currentStep < this.handlerRightStep) {
            this.setStep(currentStep, null);
          } else if(this.draggingElement === 'handlerRight' && currentStep > this.handlerLeftStep) {
            this.setStep(null, currentStep);
          }
        }
      }
    },

    updateTimelineData: function(fromTimeline) {
      var $leftStep = this.$('.steps')
        .find('[data-step-position="' + (this.handlerLeftStep-1) + '"]');
      var $rightStep = this.$('.steps')
        .find('[data-step-position="' + (this.handlerRightStep-1) + '"]');

      var startDate = $leftStep.find('.step-value').data('date');
      var endDate = $rightStep.find('.step-value').data('date');

      this.startDate = moment(startDate, 'YYYY').format('YYYY');
      this.endDate = moment(endDate, 'YYYY').format('YYYY');

      if(!fromTimeline) {
        this.model.set({
          step: this.currentStep,
          currentStartDate: this.startDate,
          currentEndDate: this.endDate
        });
      }
    },

    setDate: function(start, end) {
      var $leftStep = this.$('.steps')
        .find('[data-date="' + start + '"]').parent('.step');
      var $rightStep = this.$('.steps')
        .find('[data-date="' + end + '"]').parent('.step');

      var startPos = parseInt($leftStep.attr('data-step-position'), 10) + 1;
      var endPos = parseInt($rightStep.attr('data-step-position'), 10) + 1;

      this.setStep(startPos, endPos);
    },

    render: function(layerSlug, dashTimelineEl) {
      this.$el.html(this.template({ data: this.data }));
      this.setHandlerElements();
      this.setDate(this.model.get('startDate'), this.model.get('endDate'));
      this.show();
      dashTimelineEl.removeClass('loading');

      this.dashboardTimelines[layerSlug] = new DashboardTimeline({
        el: dashTimelineEl,
        dateStart: this.model.get('startDate'),
        dateEnd: this.model.get('endDate'),
        step: this.stepNumber,
        currentStartDate: this.model.get('currentStartDate'),
        currentEndDate: this.model.get('currentEndDate')
      });

      this.dashboardTimelines[layerSlug].listenTo(
        this.dashboardTimelines[layerSlug],
        'timeline:step', this.setStepFromTimeline.bind(this));

      this.updateLayer();
    },

    show: function(layerSlug) {
      var $body = $('body');
      $body.addClass('is-timeline-active');
    },

    hide: function(layerSlug) {
      var $body = $('body');
      var self = this;
      $body.removeClass('is-timeline-active');
      this.$el.one('webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend',
        function(e) {
          if(!$body.hasClass('is-timeline-active')){
            self.$el.html('');
          }
      });
      this.removeDashboardTimeline(layerSlug);
    },

    updateLayer: function() {
      var tablename = 'utm_built_1971_2006_130509';
      var startDate = this.model.get('currentStartDate');
      var endDate = this.model.get('currentEndDate');
      var cartocss = '#%1 [year >= %2][year <= %3] {polygon-opacity: 1;}'.format(tablename, startDate, endDate);

      if(!this.defaultCartocss) {
        this.defaultCartocss = this.layer.options.params.cartocss
      }

      this.layer.options.params.cartocss = this.defaultCartocss + cartocss;

      this.layer.updateLayer();
    },

    setStepFromTimeline: function(start, end) {
      this.setStep(start, end);
      this.updateTimelineData();
      this.updateLayer();
    },

    removeDashboardTimeline: function(layerSlug) {
      if(this.dashboardTimelines[layerSlug]) {
        this.dashboardTimelines[layerSlug].unSetListeners();
        this.dashboardTimelines[layerSlug].stopListening();
        this.dashboardTimelines[layerSlug].unbind();
        delete this.dashboardTimelines[layerSlug];
      }
    }
  });

  return TimelineView;

});
