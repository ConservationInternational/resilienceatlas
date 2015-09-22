(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.InfoWindow = Backbone.View.extend({

    el: 'body',

    template: HandlebarsTemplates['info_window_tpl'],

    events: {
      'click .btn-close' : 'close'
    },


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
    },

    render: function(data) {

      var description = data.description || null;
      var source = data.source || null;
      var link = data.source || null;

      this.infoWindow = this.template({
        'description': description,
        'source': source,
        'link': link
      });

      this.$el.append( this.infoWindow );
    },

    close: function() {
      console.log('hola');
      this.infoWindow.delete();
    }

  });

})(this);
