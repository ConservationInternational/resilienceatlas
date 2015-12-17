(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.JourneysIndexView = Backbone.View.extend({

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.journeys = settings.journeys;

      this.cacheVars();

    },

    template: HandlebarsTemplates['journeys/journey_introlist_tpl'],

    el: '#journeyIndexView',

    events: {
    },


    cacheVars: function(){
      this.$journey__introlist = $('.m-journey__grid');
    },

    render: function() {
      this.$journey__introlist.html(this.template({
        journeys: this.journeys.toJSON()
      }));
    },


  });

})(this);
