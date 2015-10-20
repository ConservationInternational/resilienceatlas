(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.analysisSelectors = Backbone.View.extend({

    events: {
    },

    el: 'analyzeSelectorsView',

    template: HandlebarsTemplates['analyze_selectors_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.setListeners();
      this.render();
    },

    setListeners: function() {
    },

    render: function() {
      console.log('hola');
    }

  });

})(this);
