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
   *     zindex: 1,
   *     group: 1,
   *     active: true,
   *     published: true
   *   }
   * ]
   */
  root.app.Collection.Layers = Backbone.Collection.extend({

    comparator: function(d) {
      return d.attributes.order ? d.attributes.order * 1000 : d.attributes.name;
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
          order: d.attributes.order || 0,
          zindex: d.attributes.zindex,
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
      var data = this.toJSON();
      if (!this._groups || !this._categories) {
        console.info('There aren\`t groups setted.');
        return this.toJSON();
      }
      return _.map(this._groups, function(g) {
        var categories = _.where(this._categories, { father: g.id });
        return _.extend(g, {
          categories: _.map(categories, function(c) {
            return _.extend(c, { layers: _.where(data, { group: c.id }) });
          })
        });
      }, this);
    },

    getActived: function() {
      return _.where(this.toJSON(), { active: true });
    }

  });


})(this);
