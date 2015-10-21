(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Widget = Backbone.View.extend({

    cartoOptions: {
      user: 'grp',
      sql_api_template: 'https://grp.global.ssl.fastly.net/user/{user}'
    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.slug = 'widget-' + this.options.slug;
      this.name = this.options.name;
      this.query = this.options.query;
      this.iso = this.options.iso;

      this.getData();
    },

    getData: function() {
      var self = this;
      if(this.query) {
        var SQL = new cartodb.SQL(this.cartoOptions);
        var query = this.query.replace(/%1/, this.iso);

        SQL.execute(query).done(function(res) {
          self.data = self.parseData(res);
          self.render();
        });
      } else {
        this.render();
      }
    },

    render: function() {
      if(!this.data || !this.data.length > 0) {
        this.noData = true;
      }

      this.$el.append(this.template({
        slug: this.slug,
        name: this.name,
        noData: this.noData,
        data: this.data
      }));

      if(!this.noData) {
        this.renderWidget();
      }
    }

  });

})(this);