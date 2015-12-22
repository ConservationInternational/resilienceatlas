(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Journeys = Backbone.View.extend({

    el: '#journeyView',

    events: {
      'click #btn-prev' :'_changeStep',
      'click #btn-next' :'_changeStep',
      'click .btn-colapse' : '_togglePanel',
      'click .btn-descolapse' : '_togglePanel',
      'click .scrolldown-link' : '_scrollPanelText',
      'click .btn-check-it' : '_viewMapClicked'
    },

    templates: {
      landing: HandlebarsTemplates['journeys/journey_landing_tpl'],
      chapter: HandlebarsTemplates['journeys/journey_chapter_tpl'],
      embed: HandlebarsTemplates['journeys/journey_embed_tpl'],
      text: HandlebarsTemplates['journeys/journey_text_tpl'],
      chart: HandlebarsTemplates['journeys/journey_chart_tpl'],
      conclusion: HandlebarsTemplates['journeys/journey_conclusion_tpl'],
      controls: HandlebarsTemplates['journeys/journey_controls_tpl']
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this._setListeners();

      this.journey = settings.journey.toJSON()[0];
      this.totalJourneys = settings.totalJourneys;

      var stepFromUrl = settings.currentStep || this.model.defaults.step;

      this._setStep(stepFromUrl);
      this.render();
    },


    _setListeners: function() {
      this.listenTo(this.model, 'change:step', this.render);
      $(document).on('keydown', _.bind(this._changeStep, this));
    },

    _currentData: function() {
      this.currentStepData = _.where(this.journey.steps, { 'number': this._getStep() });
      this.currentStepData = this.currentStepData[0];
      console.log(this.currentStepData);
      this.currentJourneyData = {'id': this.journey.id };
    },

    _currentTemplate: function() {
      var templateType = this.currentStepData.type;
      this.template = this.templates[templateType];
    },

    _cacheVars: function() {
      this.$scrollText = $('.scroll-text');
      this.$scrollContainer = $('.scroll-container');
      this.$scrollWrapper = $('.scroll-wrapper');
      this.$scrolldownLink = $('.scrolldown-link');
    },


    render: function() {
      this._currentData();
      this._currentTemplate();
      this.$el.html( this.template({ 'content': this.currentStepData, 'journey': this.currentJourneyData }) );

      this.renderButtons();


      if (this.currentStepData.type === 'embed') {
        this.renderLegend();
      };

      this._cacheVars();
      this.renderScrolldown();
    },

    renderButtons: function() {
      $('.m-controls').html( this.templates['controls'] );
      this._handleButtons();
    },

    renderScrolldown: function(){
      if(this.$scrollWrapper.height() > this.$scrollText.height()) {
        //show scroll arrow -> enable scroll functionality
        this.$scrolldownLink.removeClass('is-hidden');
        this.$scrolldownLink.addClass('is-jumping');
      }
    },

    renderLegend: function() {
      var url = this.currentStepData.mapUrl;
      var codeLayers = url.split('?')[1];
      var layers = this._unserializeParams(codeLayers);

      //trampita
      var layersCollection = new root.app.Collection.Layers();

      var complete = _.invoke([
        layersCollection
      ], 'fetch');


      $.when.apply($, complete).done(function() {
        layers = JSON.parse(layers.layers);
        layersCollection.setActives(layers)

        var legendView = new root.app.View.Legend({
          el: '#legendView',
          layers: layersCollection,
          model: new (Backbone.Model.extend({
            defaults: {
              hidden: false,
              journeyMap: true
            }
          })),
        });

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
      var totalSteps = this.journey.steps.length;

      if (mode === 'add' || keyCode === 39) {
        currentStep = currentStep === totalSteps ? currentStep : currentStep + 1;

        if (keyCode === 39 && currentStep === totalSteps) {
          window.location.href = this._getNextJourneyUrl();
          return
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
      var totalJourneys = this.totalJourneys;
      var currentJourney = this.journey.id;
      var nextJourney = currentJourney === totalJourneys ? 1 : currentJourney + 1;
      return '/journeys/' + nextJourney;
    },

    _togglePanel: function(e) {
      $('.btn-colapse').removeClass('is-hidden');
      $('.btn-descolapse').removeClass('is-hidden');
      $(e.currentTarget).addClass('is-hidden');
      var content = $('.content');
      content.toggleClass('is-colapsed');

      if (content.hasClass('is-colapsed')) {
        ga('send', 'event', 'Journeys', 'Minimise text box');
      }
    },

    _scrollPanelText: function(e) {
      var scrollAmount = this.$scrollText[0].scrollHeight - this.$scrollContainer.height();
      this.$scrollText.animate({ scrollTop: scrollAmount }, 800);
    },

    _viewMapClicked: function(e) {
      var journeyInfo = "J" + e.target.dataset.journey;
      var stepInfo = "S" + e.target.dataset.step;

      var mapInfo = journeyInfo + " " + stepInfo; // => "J1 S5" for Journey 1, Step 5

      ga('send', 'event', 'Journeys', 'View on Map', mapInfo)
    }

  });

})(this);
