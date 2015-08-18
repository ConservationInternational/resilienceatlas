(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Journeys = Backbone.View.extend({

    el: '#journeyView',

    events: {
      'click #btn-prev':'_changeStep',
      'click #btn-next':'_changeStep'
    },

    templates: {
      landing: HandlebarsTemplates['journey_landing_tpl'],
      chapter: HandlebarsTemplates['journey_chapter_tpl'],
      embed: HandlebarsTemplates['journey_embed_tpl'],
      text: HandlebarsTemplates['journey_text_tpl'],
      chart: HandlebarsTemplates['journey_chart_tpl'],
      controls: HandlebarsTemplates['journey_controls_tpl']
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this._setListeners();

      this.journey = settings.journey.toJSON()[0];

      var stepFromUrl = settings.currentStep || this.model.defaults.step;

      this._setStep(stepFromUrl);
      this.render();
    },


    _setListeners: function() {
      this.listenTo(this.model, 'change:step', this.render);
    },

    _currentData: function() {
      this.currentStepData = _.where(this.journey.steps, { number: this._getStep() });
      this.currentStepData = this.currentStepData[0];
    },

    _currentTemplate: function() {
      var templateType = this.currentStepData.type;
      this.template = this.templates[templateType];
    },


    render: function() {
      this._currentData();
      this._currentTemplate();

      this.$el.html( this.template({ content: this.currentStepData }) );

      this.renderButtons();
    },

    renderButtons: function() {
      $('.m-controls').html( this.templates['controls'] );
      this._handleButtons();
    },


    //Handle steps
    _getStep: function() {
      return this.model.get('step');
    },

    _setStep: function(step) {
      this.model.set('step', step);
    },

    _changeStep: function(e) {
      e.preventDefault();

      var mode = $(e.currentTarget).attr('mode');
      var currentStep = this._getStep();
      var totalSteps = this.journey.steps.length - 1;

      if (mode === 'add') {
        currentStep += 1;
        currentStep = currentStep > totalSteps ? 0 : currentStep;
      } else {
        currentStep -= 1;
        currentStep = currentStep < 0 ? totalSteps : currentStep;
      }

      this._handleButtons(currentStep, totalSteps);
      this._setStep(currentStep);
    },

    _handleButtons: function() {
      var currentStep = this._getStep();
      var totalSteps = this.journey.steps.length - 1;

      var noNext = currentStep === totalSteps ? true : false;
      var noPrev = currentStep === 0 ? true : false;

      $('#btn-next').toggleClass('is-hidden', noNext);
      $('#btn-prev').toggleClass('is-hidden', noPrev);
    }
  });

})(this);