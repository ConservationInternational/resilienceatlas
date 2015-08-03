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
   *     category: 'lorem-ipsum',
   *     group: 'lorem-ipsum',
   *     active: true,
   *     published: true
   *   }
   * ]
   */
  root.app.Collection.Layers = Backbone.Collection.extend({

    comparator: 'order',

    url: '/api/layers',

    parse: function(response) {
      var result = _.map(response.data, function(d) {
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
          category: null,
          group: { id: parseInt(d.relationships.layer_group.data.id) },
          active: d.attributes.active,
          published: d.attributes.published
        };
      });
      // console.log(response.data);
      return result;
    },

    getGrouped: function() {
      var result = [];
      var data = this.toJSON();
      _.each(data, function(d) {
        var group = _.findWhere(result, { id: d.group.id });
        if (group) {
          group.values.push(d);
        } else {
          group = { id: d.group.id, layers: [d] };
          result.push(group);
        }
      });
      return result;
    }

  });


})(this);
