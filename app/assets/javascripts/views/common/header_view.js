(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Header = Backbone.View.extend({

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.journeys = settings.journeys;
      this.cacheVars();
      this.setListeners();
    },

    template: HandlebarsTemplates['journeys/journeys_tpl'],

    model: new (Backbone.Model.extend({
      defaults: {
        visibility: false
      }
    })),

    events: {
      // 'click .journey-link' : 'toggle',
    },

    render: function() {
      this.$journey__paginationlist.html(this.template({
        journeys: this.journeys.toJSON()
      }));
    },

    setListeners: function() {
      this.listenTo(this.model,'change:visibility', this.changeVisibility);
      this.$backdrop.on('click', _.bind(this.hide,this));
    },


    cacheVars: function() {
      this.$backdrop = $('#backdrop');
      this.$journey__paginationlist = this.$el.find('.m-journey__paginationlist');
    },

    show: function(e) {
      this.model.set('visibility', true);
    },

    hide: function(e) {
      this.model.set('visibility', false);
    },

    //Shows journeys menu
    // toggle: function(e) {
    //   e && e.preventDefault();
    //   this.model.set('visibility', !this.model.get('visibility'));
    // },

    changeVisibility: function() {
      this.$backdrop.toggleClass('is-active', this.model.get('visibility'));
      this.$journey__paginationlist.toggleClass('is-active', this.model.get('visibility'));
    },

  });

})(this);
