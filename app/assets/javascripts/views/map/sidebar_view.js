(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Sidebar = Backbone.View.extend({

    el: '#sidebarView',

    template: HandlebarsTemplates['map/sidebar_tpl'],

    events: {
    },

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.render();
    },

    render: function() {
      this.$el.html(this.template);
      $(document).foundation('tab', 'reflow');
    }
  });

})(this);
