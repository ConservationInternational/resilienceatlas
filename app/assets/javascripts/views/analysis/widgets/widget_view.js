(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Widget = Backbone.View.extend({

    cartoOptions: {
      user: 'grp',
      sql_api_template: 'https://grp.global.ssl.fastly.net/user/{user}'
    },

    templateWidget: HandlebarsTemplates['analysis/widgets/widget_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.slug = 'widget-' + this.options.slug;
      this.name = this.options.name;
      this.query = this.options.query;
      this.iso = this.options.iso;
      this.unit = this.options.unit || '';
      this.unitZ = this.options.unitZ || '';
      this.widgetName = this.options.widgetName || '';
      this.labels = this.options.labels;

      this.render();
    },

    getData: function() {
      var self = this;
      if(this.query) {
        var SQL = new cartodb.SQL(this.cartoOptions);
        var query = this.query.replace(/%1/, this.iso);

        SQL.execute(query).done(function(res) {
          self.data = self.parseData(res);
          self.renderContent();
        });
      } else {
        this.renderContent();
      }
    },

    render: function() {
      this.$el.append(this.templateWidget({
        widgetName: this.widgetName,
        slug: this.slug,
      }));

      _.delay(this.getData.bind(this), 500);
    },

    renderContent: function() {
      var $el = this.$('#' + this.slug);

      if(!this.data || !this.data.length > 0) {
        this.noData = true;
      }

      $el.html(this.template({
        name: this.name,
        noData: this.noData,
        data: this.data,
        slug: this.slug
      }));

      if(!this.noData) {
        this.renderWidget();
      }

      $el.removeClass('is-loading');
      $el.addClass('loaded');      
    }

  });

})(this);