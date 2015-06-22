define([
  'backbone',
  'underscore',
  'handlebars',
  'lib/utils',
  'text!templates/map/analysis_view_tpl.handlebars'
], function(Backbone, _, Handlebars, utils, TPL) {

 'use strict';

  var AnalysisView = Backbone.View.extend({

    el: '#analysisView',

    events: {
      'click .tab' : 'toggleTabs',
      'click #discard-analysis' : 'discard'
    },

    template: Handlebars.compile(TPL),

    initialize: function() {
      this.render();
      this.cacheVars();
      this.setListeners();
    },

    cacheVars: function(){
      this.$body = $('body');
      this.$tabs = this.$el.find('.tab');
      this.$tabsContent = this.$el.find('.tab-content');
    },

    setListeners: function() {
      Backbone.Events.on('drawing:analyze', this.analyze, this);
      Backbone.Events.on('drawing:delete', this.hide, this);
    },

    analyze: function(layer){
      this.layer = layer;
      this.show();
    },

    render: function() {
      this.$el.html(this.template());
    },

    show: function() {
      this.$body.addClass('analysis-opened');
    },

    hide: function(){
      this.$body.removeClass('analysis-opened');
    },

    discard: function(){
      Backbone.Events.trigger('analysis:delete');
    },

    toggleTabs: function(e){
      var active = $(e.currentTarget).hasClass('active');
      this.$tabs.removeClass('active');
      this.$tabsContent.removeClass('active');
      if (!active) {
        $(e.currentTarget).addClass('active');
        $(e.currentTarget).parent().find('.tab-content').addClass('active');
      }
    }

  });

  return AnalysisView;
});
