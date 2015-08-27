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
   *     father: 1,
   *     order: 1,
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
    comparator: 'order',

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
      console.log(result);
      return result;
    },

    getGroups: function() {
      return _.filter(this.getPublished(), function(g) {
        return !!!g.father;
      });
    },

    getCategories: function() {
      return _.filter(this.getPublished(), function(g) {
        return !!g.father;
      });
    },

    getCategoriesByGroup: function(groupId) {
      return _.filter(this.getPublished(), function(g) {
        return groupId === g.father;
      });
    },

    getPublished: function() {
      // TODO: add published column to layers groups
      // return _.where(this.toJSON(), { published: true });
      return this.toJSON();
    }

  });


})(this);
