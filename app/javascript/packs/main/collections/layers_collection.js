(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  /**
   * Layers collection
   *
   * [
   *   {
   *     id: 1,
   *     slug: 'lorem-ipsum',
   *     name: 'Lorem ipsum',
   *     type: 'cartodb',
   *     description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
   *     cartocss: '#table_name {marker-fill: #F0F0F0;}',
   *     sql: 'SELECT * FROM table_name',
   *     color: '#ff0000',
   *     opacity: 1,
   *     order: 1,
   *     group: 1,
   *     active: true,
   *     published: true,
   *     dataset_shortname: 'dataset-name',
   *     dataset_source_url: 'http://www.dataset-name-url.com/',
   *   }
   * ]
   */
  root.app.Collection.Layers = Backbone.Collection.extend({

    comparator: function(d) {
      return ((d.attributes.dashboard_order || 0) + 1000) + d.attributes.name;
    },

    url: function() {
      return '/api/layers?lang=' + window.currentLocation || 'en';
    },

    // order : 1,

    parse: function(response) {
      var self = this;
      var result = _.map(response.data, _.bind(function(d) {
        var group = d.relationships.layer_group.data;
        return {
          id: parseInt(d.id),
          slug: d.attributes.slug,
          name: d.attributes.name,
          type: d.attributes.layer_provider,
          description: d.attributes.info,
          cartocss: d.attributes.css,
          interactivity: d.attributes.interactivity,
          sql: d.attributes.query,
          color: d.attributes.color,
          opacity: d.attributes.opacity,
          no_opacity: d.attributes.opacity == 0 ? true : false,
          order: d.attributes.order || null,
          maxZoom: d.attributes.zoom_max || 100,
          minZoom: d.attributes.zoom_min || 0,
          legend: d.attributes.legend,
          group: group ? parseInt(group.id) : null,
          active: d.attributes.active,
          published: d.attributes.published,
          info: d.attributes.info,
          dashboard_order: d.attributes.dashboard_order,
          download: d.attributes.download || null,
          download_url: d.attributes.download ? this._generateDownloadUrl(d) : null,
          dataset_shortname: d.attributes.dataset_shortname || null,
          dataset_source_url: d.attributes.dataset_source_url || null,
          attributions: d.relationships && d.relationships.sources && d.relationships.sources.data && d.relationships.sources.data.length > 0 && this._getReference(response.included, d.relationships.sources.data),
          analysisSuitable: d.attributes.analysis_suitable,
          analysisQuery: d.attributes.analysis_query,
          layerProvider: d.attributes.layer_provider
        };
      }, this));
      return result;
    },

    _generateDownloadUrl: function(d) {
      return window.userlogged === "true" ? '/api/layers/'+ d.id+ '/downloads?file_format=kml&with_format=true&download_path=https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql?filename=' + d.attributes.slug + '&q=' + encodeURIComponent(d.attributes.query) : '/users/login';
    },

    _getReference: function(attributes, sources) {
      var attributions = [];

      _.each(sources, function(source) {
        var attribution = _.find(attributes, {id: source.id});
        attributions.push(attribution);
      });

      return attributions;
    },

    setGroups: function(groupsCollection) {
      this._groups = _.sortBy(groupsCollection.getGroups(), 'order');
      this._categories = _.sortBy(groupsCollection.getCategories(), 'order');
      this._subcategories = _.sortBy(groupsCollection.getsubCategories(), 'order');
      this._subGroups = _.sortBy(groupsCollection.getsubGroups(), 'order');
      return this;
    },

    getGrouped: function() {
      var data = this.getPublished();
      if (!this._groups || !this._categories) {
        console.info('There aren\`t groups setted.');
        return this.toJSON();
      }

      return _.map(this._groups, function(g) {

        var groupLayers = _.where(data, { group: g.id });
        _.map(groupLayers, function(layer){
          layer.opacity_text = layer.opacity*100
          return layer;
        });

        // Forcing category activation
        var isActive = _.contains(_.pluck(groupLayers, 'active'), true);
        if (isActive) {
          g.active = true;
        } else {
          g.active = false;
        }

        var categories = _.where(this._categories, { father: g.id });

        return _.extend(g, {
          layers: _.sortBy(groupLayers, 'dashboard_order'),

          categories: _.map(categories, function(c) {
            var layers = _.where(data, { group: c.id });
            _.map(layers, function(layer){
              layer.opacity_text = layer.opacity*100
              return layer;
            });

            // Forcing category activation
            var isActive = _.contains(_.pluck(layers, 'active'), true);
            if (isActive) {
              c.active = true;
            } else {
              c.active = false;
            }

            //Hayo las subcategories para esta categoria.
            var subcategories = _.where(this._subcategories, { father: c.id });
            //Extend categories with their subcat.
            _.extend(c, {
              subcategory: _.map(subcategories, function(sc) {
                var layers = _.where(data, { group: sc.id });
                _.map(layers, function(layer){
                  layer.opacity_text = layer.opacity*100
                  return layer;
                });
                // Forcing category activation
                var isActive = _.contains(_.pluck(layers, 'active'), true);
                if (isActive) {
                  sc.active = true;
                } else {
                  sc.active = false;
                }

                var subgroups = _.where(this._subGroups, { father: sc.id });
                _.extend(sc, {
                  subgroup: _.map(subgroups, function(sg) {
                    var layers = _.where(data, { group: sg.id });
                    _.map(layers, function(layer){
                      layer.opacity_text = layer.opacity*100
                      return layer;
                    });
                    // Forcing category activation
                    var isActive = _.contains(_.pluck(layers, 'active'), true);
                    if (isActive) {
                      sg.active = true;
                    } else {
                      sg.active = false;
                    }
                    return _.extend(sg, { layers: _.sortBy(layers, 'dashboard_order') });
                  }, this)
                })

                return _.extend(sc, { layers: _.sortBy(layers, 'dashboard_order') });
              }, this)
            })

            return _.extend(c, { layers: _.sortBy(layers, 'dashboard_order') });
          }, this)
        });

      }, this);
    },

    setActives: function(activeLayers) {
      var self = this;

      $.each(this.models, function() {
        this.set('active', false);
      });

      $.each(activeLayers, function() {
       var activelayer = _.findWhere(self.models, { id: this['id'] });
       activelayer.set('active', true);
       activelayer.set('order', this['order']);
      });
    },

    _setNoOpacity: function() {
      //Set no_opacity value to manage legend visibility.
      var self = this;
      var noOpacityLayers = _.where(this.toJSON(), { opacity: 0 });

      $.each(noOpacityLayers, function() {
        var noOpacityLayer = _.findWhere(self.models, { id: this['id'] });
        noOpacityLayer.set('no_opacity', true);
      });
    },

    setDisabledByZoom: function(layerId) {
      var noAvailableByZoom = _.findWhere(this.models, { 'id': layerId });
      noAvailableByZoom.set('notAvailableByZoom', true);

      Backbone.Events.trigger('legend:render');
    },

    unsetDisabledByZoom: function(layerId) {
      var noAvailableByZoom = _.findWhere(this.models, { 'id': layerId });
      noAvailableByZoom.set('notAvailableByZoom', false);

      Backbone.Events.trigger('legend:render');
    },

    setOrder: function(layerId) {
      this.order = this.order || this.getMaxOrderVal() + 1;

      var current = _.findWhere(this.models, { 'id': layerId });
      current.set('order', this.order);

      return ++ this.order
    },

    setOrderToNull: function(layerId) {
      var current = _.findWhere(this.models, { 'id': layerId });
      current.set('order', null);
    },

    getMaxOrderVal: function() {
      return _.max(_.map(this.toJSON(), function(layer) {
        return layer.order
      }), function(i) {
        return i
      });
    },

    getActived: function() {
      this._setNoOpacity();
      return _.where(this.toJSON(), { active: true, published: true });
    },

    getPublished: function() {
      this._setNoOpacity();
      return _.where(this.toJSON(), { published: true });
    },

    getCategories: function() {
      var categories = _.flatten(_.pluck(this.getGrouped(), 'categories'));
      return categories;
    },

    getActiveLayers: function() {
      var layers = [];
      var activeLayers = this.where({ active: true });

      _.each(activeLayers, function(layer) {
        layers.push(layer.toJSON());
      });

      return layers;
    },

  });


})(this);
