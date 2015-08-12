(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Journeys = Backbone.View.extend({

    el: '#journeyView',

    templates: {
      landing: HandlebarsTemplates['journey_landing_tpl'],
      chapter: HandlebarsTemplates['journey_chapter_tpl'],
      embed: HandlebarsTemplates['journey_embed_tpl'],
      text: HandlebarsTemplates['journey_text_tpl'],
      chart: HandlebarsTemplates['journey_chart_tpl'],
    },

    model: new (Backbone.Model.extend({
      defaults: {
        journey: 1,
        step: 0
      }
    })),

    events: {
      'click #btn-prev':'changeStep',
      'click #btn-next':'changeStep'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.setListeners();
      this.journey = settings.journey.toJSON()[0];

      this.startJourney();
    },

    setListeners: function() {
      this.listenTo(this.model, 'change:step', this.startJourney);
    },


    startJourney: function() {
      this.currentData()
      this.currentTemplate();

      this.render();
    },

    currentData: function() {
      this.currentStepData = _.where(this.journey.steps, {number: this.getStep()});
      this.currentStepData = this.currentStepData[0];
    },

    currentTemplate: function() {
      var templateType = this.currentStepData.type;
      this.template = this.templates[templateType];
    },


    render: function() {
      this.$el.html( this.template({ content: this.currentStepData }) );
    },


    //Handle steps
    getStep: function() {
      return this.model.get('step');
    },

    setStep: function(step) {
      this.model.set('step', step);
    },

    changeStep: function(e) {
      e.preventDefault();

      var mode = $(e.currentTarget).attr('mode');
      var currentStep = this.getStep();
      var totalSteps = this.journey.steps.length - 1;

      if (mode === 'add') {
        currentStep += 1;
        currentStep = currentStep > totalSteps ? 0 : currentStep;
      } else {
        currentStep -= 1;
        currentStep = currentStep < 0 ? totalSteps : currentStep;
      }

      this.setStep(currentStep);
    }

  });

})(this);
