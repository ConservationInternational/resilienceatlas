define([
  'backbone',
  'models/map_model'
], function(Bakcbone, MapModel) {

  var dashboardNavigationView = Backbone.View.extend({

      events: {
        //'click .tabs a' : 'active'
      },

      initialize: function() {
        this.model = MapModel;
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
