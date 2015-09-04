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
          no_opacity: function() {
            var currentOpacity = d.attributes.opacity
            console.log(currentOpacity);
            if (currentOpacity === 0) {
              return true;
            } else {
              return false
            }
          },
          order: d.attributes.order || 0,
          legend: d.attributes.legend,
          group: group ? parseInt(group.id) : null,
          active: d.attributes.active,
          published: d.attributes.published
        };
      });

      return result;
    },

    setGroups: function(groupsCollection) {
      this._groups = groupsCollection.getGroups();
      this._categories = groupsCollection.getCategories();
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
            return _.extend(c, { layers: layers });
          })
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

    getActived: function() {
      //If we sort by order, it changes position at dashboard.
      return _.where(this.toJSON(), { active: true, published: true });
      // return _.where(_.sortBy(this.toJSON(), 'order'), { active: true, published: true });
    },

    getPublished: function() {
      //If we sort by order, it changes position at dashboard.
      return _.where(this.toJSON(), { published: true });
      // return _.where(_.sortBy(this.toJSON(), 'order'), { published: true });
    },

    getCategories: function() {
      var categories = _.flatten(_.pluck(this.getGrouped(), 'categories'));
      return categories;
    },

  });


})(this);
