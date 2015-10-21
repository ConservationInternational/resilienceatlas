(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Advise = Backbone.View.extend({

    el: '#adviseView',

    template: HandlebarsTemplates['common/advise_tpl'],

    events: {
      'click .btn-close' : '_hide'
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.render();
    },

    render: function() {
      var name = this.options.name;
      this.$el.html(this.template({ 'layerName' : name }));

      setTimeout(_.bind(this._show, this), 300);
    },

    _show: function(argument) {
      this.$el.addClass('is-active');

      // setTimeout(_.bind(this._hide, this), 5000);
    },

    _hide: function() {
      this.$el.removeClass('is-active');
    }

  });

})(this);
