(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Toolbar = Backbone.View.extend({

    el: '#toolbarView',

    template: HandlebarsTemplates['map/toolbar_tpl'],

    events: {
      'click .btn-share' : '_share',
      'click .btn-analyze' : '_analyze',
      'click .btn-export-to-pdf': '_exportMapToPDF'
    },

    _getExportUrl: function() {
      return 'https://www.resilienceatlas.org/webshot?filename=export-map-' + new Date().getTime() + '.pdf' +
        '&url=' + window.location.href;
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.render();
    },

    render: function() {
      const template = this.template({ downloadURL: this._getExportUrl() });
      this.$el.html(template);
    },

    _share: function() {
      Backbone.Events.trigger('share:show');
    },

    _analyze: function() {
      var analyze = new root.app.View.analysisSelectors();
    },

    _exportMapToPDF: function(e) {
      var exportLink = e.currentTarget;
      exportLink.setAttribute('href', this._getExportUrl());
      window.open(this._getExportUrl(), '_blank');
      return false;
    }

  });

})(this);
