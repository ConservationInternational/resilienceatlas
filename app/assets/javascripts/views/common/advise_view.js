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
      
      this.collection = new Backbone.Collection.extend({
        model: new Backbone.Model.extend({
          id: null,
          name: null
        })
      });
      
      this.collection.set('hola', 'holita');
      this.setListeners();
    },

    setListeners: function() {
      // this.listenTo(this.collection, 'change', this.render);
    },

    render: function() {
      var data = this.collection;
      // console.log(data);
      // return
      var name = this.options.name;
      this.$el.append(this.template({ 'layerName' : name }));



    },

    _show: function(argument) {
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
