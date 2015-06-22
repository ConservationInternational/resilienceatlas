define([
  'backbone',
  'underscore',
  'handlebars',
  'moment',
  'lib/utils',
  'text!templates/map/dashboard_timeline_tpl.handlebars'
], function(Backbone, _, Handlebars, moment, utils, TPL) {

  'use strict';

  var DashboardTimelineView = Backbone.View.extend({

    events: {
      'mousedown .handlerLeft': 'handlerDown',
      'mousedown .handlerRight': 'handlerDown',
      'mousemove': 'handlerMove',
      'mouseup': 'handlerUp',
      'mouseleave': 'handlerUp'
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

      this.dateStart = parseInt(this.options.dateStart, 10);
      this.dateEnd = parseInt(this.options.dateEnd, 10);
      this.currentStartDate = parseInt(this.options.currentStartDate, 10);
      this.currentEndDate = parseInt(this.options.currentEndDate, 10);

      this.margin = this.options.margin;
      this.stepNumber = this.options.step || this.options.groupStep;

      this.leftHandle = this.options.leftHandle;
      this.rightHandle = this.options.rightHandle;

      this.steps = _.range(this.dateStart, this.dateEnd + 1);
      this.groupStep = Math.round(this.steps.length / this.stepNumber);
      this.stepsLength = this.steps.length;
      this.stepsWidth = 100 / (this.stepsLength + this.margin);
      this.dragging = false;

      this.setListeners();

      this.render();
    },

    setListeners: function() {
      Backbone.Events.on('timeline:changed', this.updateStep.bind(this));
    },

    unSetListeners: function() {
      Backbone.Events.off('timeline:changed');
    },

    render: function() {
      var self = this;
      var stepsData = [];
      var dateStart = this.dateStart;
      var dateEnd = this.dateEnd;
      var groupStep = this.groupStep-3;
      var groupLimit =  Math.round(this.steps.length / groupStep);
      var contSteps = 0;

      var groupsRange = _.range(dateStart, dateEnd, groupStep);
      groupsRange[0] = this.dateStart;
      groupsRange[groupsRange.length - 1] = this.dateEnd;

      _.map(this.steps, function(step, i) {
        contSteps++;
         var stepData = {
          step: step,
          groupClass: ''
        };

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

      this.$el.html(this.template({data: this.data}));
      this.setHandlerElements();
      this.setDate(this.currentStartDate, this.currentEndDate);

      var self = this;
    },

    getGroups: function() {
      var dateStart = this.dateStart;
      var dateEnd = this.dateEnd;
      var groupStep = this.groupStep;

      var groupsRange = _.range(dateStart, dateEnd, groupStep);
      groupsRange[0] = this.dateStart;
      groupsRange[groupsRange.length - 1] = this.dateEnd;

      var groupsData = {
        data: groupsRange,
        groupsWidth: 100 / groupsRange.length
      };

      return groupsData;
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
        this.triggerChanges(this.handlerLeftStep, this.handlerRightStep);
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
        this.$(this.leftHandle).css('left', (leftPos) + '%');

        this.handlerLeftStep = leftStep;
      }
      if(rightStep >= 0 && rightStep !== null) {
        var rightPos = (rightStep * this.stepsWidth) + (this.stepsWidth / 2);
        var rightHandleWidth = ((this.$(this.leftHandle).width() / 2) / stepsWidth) * this.stepsWidth;
        this.$(this.rightHandle).css('left', rightPos + '%');

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
    },

    triggerChanges: function(start, end) {
      this.trigger('timeline:step', start, end);
    },

    handlerMove: function(e) {
      if (this.dragging) {
        var $stepsContent = this.$('.steps');
        var $stepMargin = this.$('.step-margin');
        var $container = this.$el;

        var x = e.clientX || e.pageX;
        x = x - $container.offset().left;
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

    setDate: function(start, end) {
      var $leftStep = this.$('.steps')
        .find('[data-date="' + start + '"]').parent('.step');
      var $rightStep = this.$('.steps')
        .find('[data-date="' + end + '"]').parent('.step');

      var startPos = parseInt($leftStep.attr('data-step-position'), 10) + 1;
      var endPos = parseInt($rightStep.attr('data-step-position'), 10) + 1;

      this.setStep(startPos, endPos);
    },

    updateStep: function(start, end) {
      this.setDate(start, end);
    }
  });

  return DashboardTimelineView;

});
