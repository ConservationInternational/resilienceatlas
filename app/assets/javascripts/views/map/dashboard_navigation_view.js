define([
  'backbone',
  'models/map_model'
], function(Bakcbone, MapModel) {

  var dashboardNavigationView = Backbone.View.extend({

      events: {
        'click .disabled a' : 'noWay'
      },

      initialize: function() {
        this.model = MapModel;
      },

      noWay: function(e) {
        if(e) {
          e.preventDefault();
        }
      },

      setListeners: function() {
        Backbone.Events.on('dashboard-nav:change', this.setUrlParams, this);
      },

      setUrlParams: function(params) {
        if (params.hasOwnProperty('tab')) {
          this.params = {tab : params.tab};
        }

        this.update();
      },

      update: function() {
        $('.tabs').removeClass('active');
        this.$el.find('[data-item="' + this.params.tab + '"]').addClass('active');
      }

  });

  return dashboardNavigationView;

});
