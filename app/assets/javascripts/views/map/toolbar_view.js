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
      'click .btn-export': '_export'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.render();
    },

    render: function() {
      this.$el.html(this.template);
    },

    _share: function() {
      Backbone.Events.trigger('share:show');
    },

    _analyze: function() {
      var analyze = new root.app.View.analysisSelectors();
    },

    _export: function() {
      var req = new XMLHttpRequest();
      req.open('POST', '/screen', true);
      req.responseType = 'blob';
      req.setRequestHeader('Content-Type', 'application/json');

      req.onload = function (event) {
        var blob = req.response;
        var link = document.createElement('a');
        link.href = window.URL.createObjectURL(blob);
        link.download = 'Webshot_' + new Date().getTime() + '.png';
        link.click();
      };

      req.send(JSON.stringify({ url: document.location.href }));
    }

  });

})(this);
