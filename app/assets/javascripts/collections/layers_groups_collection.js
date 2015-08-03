(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  /**
   * LayersGroups collection
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
   *     category: 'lorem-ipsum',
   *     group: 'lorem-ipsum',
   *     active: true,
   *     published: true
   *   }
   * ]
   */
  root.app.Collection.LayersGroups = Backbone.Collection.extend({

    comparator: function(d) {
      return d.attributes.order ? d.attributes.order * 1000 : d.attributes.name;
    },

    url: '/api/layer-groups',

    parse: function(response) {
      var result = _.map(response.data, function(d) {
        var superGroupId = d.attributes.super_group_id;
        return {
          id: parseInt(d.id),
          slug: d.attributes.slug,
          name: d.attributes.name,
          father: superGroupId ? parseInt(superGroupId) : null,
          order: d.attributes.order,
          active: d.attributes.active
        };
      });
      return result;
    },

    getGroups: function() {
      return _.filter(this.toJSON(), function(g) {
        return !!!g.father;
      });
    },

    getCategories: function() {
      return _.filter(this.toJSON(), function(g) {
        return !!g.father;
      });
    },

    getCategoriesByGroup: function(groupId) {
      return _.filter(this.toJSON(), function(g) {
        return groupId === g.father;
      });
    }

  });


})(this);
