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
   *     published: true
   *   }
   * ]
   */
  root.app.Collection.Layers = Backbone.Collection.extend({

    comparator: function(d) {
      // return d.attributes.order ? d.attributes.order * 1000 : d.attributes.name;
      return d.attributes.name
    },

    url: '/api/layers',

    parse: function(response) {
      var result = _.map(response.data, function(d) {
        var group = d.relationships.layer_group.data;
        return {
          id: parseInt(d.id),
          slug: d.attributes.slug,
          name: d.attributes.name,
          type: d.attributes.layer_provider,
          description: d.attributes.info,
          cartocss: d.attributes.css,
          sql: d.attributes.query,
          color: d.attributes.color,
          opacity: d.attributes.opacity,
          no_opacity: d.attributes.opacity == 0 ? true : false,
          order: d.attributes.order || 0,
          legend: d.attributes.legend,
          group: group ? parseInt(group.id) : null,
          active: d.attributes.active,
          published: d.attributes.published,
          info: d.attributes.info
        };
      });

      return result;
    },

    setGroups: function(groupsCollection) {
      this._groups = groupsCollection.getGroups();
      this._categories = groupsCollection.getCategories();
      this._subcategories = groupsCollection.getsubCategories();
      return this;
    },

    getGrouped: function() {
      var data = this.getPublished();
      if (!this._groups || !this._categories) {
        console.info('There aren\`t groups setted.');
        return this.toJSON();
      }

      return _.map(this._groups, function(g) {
        var categories = _.where(this._categories, { father: g.id });

        return _.extend(g, {
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
                return _.extend(sc, { layers: layers });
              }, this)
            })

            return _.extend(c, { subcategories: subcategories, layers: layers });
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
      noAvailableByZoom.set('notAvailableByZoom', true, { silent: true });
    },

    unsetDisabledByZoom: function(layerId) {
      var noAvailableByZoom = _.findWhere(this.models, { 'id': layerId });
      noAvailableByZoom.set('notAvailableByZoom', false, { silent: true });
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
      var activeLayers = this.where({active: true});

      _.each(activeLayers, function(layer) {
        layers.push(layer.toJSON());
      });

      return layers;
    },

  });


})(this);
