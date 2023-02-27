(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Widget = Backbone.View.extend({

    sqlApi: 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql',

    templateWidget: HandlebarsTemplates['analysis/widgets/widget_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.slug = 'widget-' + this.options.slug;
      this.name = this.options.name;
      this.query = this.options.query;
      this.geojson = this.options.geojson;
      this.iso = this.options.iso;
      this.unit = this.options.unit || '';
      this.unitY = this.options.unitY || '';
      this.unitX = this.options.unitX || '';
      this.unitZ = this.options.unitZ || '';

      this.widgetName = this.options.widgetName || '';
      this.labels = this.options.labels;
      this.meta_short = this.options.meta_short;
      this.metadata = this.options.metadata;

      this.render();
    },

    getData: function() {
      var self = this;
      if(this.query) {
        var geometry = this.geojson.features
          ? this.geojson.features[0].geometry
          : this.geojson.geometry;
        var query = this.query.replace(/{{geometry}}/g, JSON.stringify(geometry));

        $.ajax({
          url: this.sqlApi,
          type: 'get',
          data: {
            q: query
          },
          success: function(res) {
            self.data = self.parseData(res);
            self.renderContent();
          },
          error: function(xhr) {
            console.warn('error ' + xhr)
          }
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
        slug: this.slug,
        meta_short: this.meta_short,
        metadata: JSON.stringify(this.metadata)
      }));

      if(!this.noData) {
        this.renderWidget();
      }

      $el.removeClass('is-loading');
      $el.addClass('loaded');
    }

  });

})(this);
