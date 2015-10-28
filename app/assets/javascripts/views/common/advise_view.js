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
      var Collection = Backbone.Collection.extend({});
      this.collection = new Collection();

      this.setListeners();
    },

    setListeners: function() {
      this.listenTo(this.collection, 'add', this._addTitle, this);
    },

    _addTitle: function() {
      var names = _.map(this.collection.models, _.bind(function(layer) {
        return layer.get('name');  
      }, this));

      console.log(names);
    
      this.$('.advise').html(this.template({ 'layerName' : name }));

      this._show();
    },

    _show: function() {
      this.$el.addClass('is-active');
      setTimeout(_.bind(this._hide, this), 5000);
    },

    _hide: function() {
      this.$el.removeClass('is-active');
      // console.log(this);
      // this.remove();
    },

    clear: function() {
      // remove events
      this.$el.html(null);
    }

  });

})(this);
