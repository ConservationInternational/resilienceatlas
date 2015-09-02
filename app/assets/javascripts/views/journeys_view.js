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
      conclusion: HandlebarsTemplates['journey_conclusion_tpl'],
      controls: HandlebarsTemplates['journey_controls_tpl']
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this._setListeners();

      this.journey = settings.journey.toJSON()[0];
      this.totalJourneys = settings.journeys;

      var stepFromUrl = settings.currentStep || this.model.defaults.step;

      this._setStep(stepFromUrl);
      this.render();
    },


    _setListeners: function() {
      this.listenTo(this.model, 'change:step', this.render);
      $(document).on('keydown', _.bind(this._changeStep, this));
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

      if (this.currentStepData.type === 'embed') {
        this.renderLegend();
      };

    },

    renderButtons: function() {
      $('.m-controls').html( this.templates['controls'] );
      this._handleButtons();
    },

    renderLegend: function() {
      var url = this.currentStepData.mapUrl;
      var codeLayers = url.split('?')[1];
      var layers = this._unserializeParams(codeLayers);

      //trampita
      // var journeyMap = this._checkJourneyMap();
      var layersCollection = new root.app.Collection.Layers();

      var complete = _.invoke([
        layersCollection
      ], 'fetch');

      var legendView = new root.app.View.Legend({
        el: '#legendView',
        layers: layersCollection,
        model: new (Backbone.Model.extend({
          defaults: {
            hidden: false,
            order: [],
          }
        })),
      });


      $.when.apply($, complete).done(function() {
        layers = JSON.parse(layers.layers);
        layersCollection.setActives(layers)

        legendView.render();
      })
    },

    _unserializeParams: function(layers) {
      var location = layers;
      var params = {};
      if (location) {
        var paramsArr = decodeURIComponent(location).split('&'),
          temp = [];
        for (var p = paramsArr.length; p--;) {
          temp = paramsArr[p].split('=');
          if (temp[1] && !_.isNaN(Number(temp[1]))) {
            params[temp[0]] = Number(temp[1]);
          } else if (temp[1]) {
            params[temp[0]] = temp[1];
          }
        }
      }
      return params;
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
      var keyCode = e.keyCode ? e.keyCode : e.charCode;
      var currentStep = this._getStep();
      var totalSteps = this.journey.steps.length - 1;

      if (mode === 'add' || keyCode === 39) {
        currentStep = currentStep === totalSteps ? currentStep : currentStep + 1;

        if (keyCode === 39 && currentStep === totalSteps) {
          window.location.href = this._getNextJourneyUrl();
        }
      } else if (mode === 'sub' || keyCode === 37) {
        currentStep = currentStep === 0 ? currentStep : currentStep - 1;

        if (keyCode === 37 && currentStep === 0) {
          //Put here code if we want to go to previus journey.
        }
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

      if (noNext) {
        this._setNextJourneyUrl();
      }
    },

    _setNextJourneyUrl: function() {
      var nextJourneyUrl = this._getNextJourneyUrl();
      $('#btn-next-journey').attr('href', nextJourneyUrl)
    },

    _getNextJourneyUrl: function() {
      var totalJourneys = 2; //Fix this with index.
      // This way below is the correct way, but is not working for
      // the moment because index y a fake one.
      // var totalJourneys = this.totalJourneys
      var currentJourney = this.journey.id;
      var nextJourney = currentJourney === totalJourneys ? 1 : currentJourney + 1;

      return '/journeys/' + nextJourney;
    }
  });

})(this);
