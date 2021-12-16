(function(root) {

  'use strict';

  root.app = root.app || {};

  root.app.JourneysPageView = Backbone.Router.extend({


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.router = settings.router;
      this.subdomainParams = settings.subdomainParams;
      this.setListeners();
      this._initJourney();
    },

    setListeners: function() {
    },

    _initJourney: function() {
      //Expected route journeys/:journeyId?&step=4
      var journeyModel = new root.app.Model.Journeys();
      var journeysCollection = new root.app.Collection.Journeys();

      //Get router params
      var routerParams = this.router.params.attributes;

      if (!routerParams.step) {
        routerParams.step = 0;
      }

      //Fetching data
      var complete = _.invoke([
        journeysCollection
      ], 'getByParams', this.options.journeyId);

      //Starting view
      $.when.apply($, complete).done(function() {
        var journeyView = new root.app.View.Journeys({
          model: journeyModel,
          journey: journeysCollection,
          totalJourneys: this.options.totalJourneys,
          currentStep: routerParams.step,
          subdomainParams: this.subdomainParams
        });
      }.bind(this));

      //Telling router to be aware of this model changes
      journeyModel.on('change', function() {
        var currentStep = journeyModel.get('step');
        this.router.setParams('step', currentStep);
      }.bind(this));
    }


  });

})(this);
