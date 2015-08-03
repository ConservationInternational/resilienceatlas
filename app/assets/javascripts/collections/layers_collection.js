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
   *     description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
   *     cartocss: '#table_name {marker-fill: #F0F0F0;}',
   *     sql: 'SELECT * FROM table_name',
   *     color: '#ff0000',
   *     order: 1,
   *     zindex: 1,
   *     category: 1,
   *     active: true,
   *     published: true
   *   }
   * ]
   */
  root.app.Collection.Layers = Backbone.Collection.extend({

    comparator: 'order',

    url: '/api/layers',

    parse: function(response) {
      return response;
    },

    getByCategory: function() {
      return _.groupBy(this.toJSON(), 'category');
    }

  });


})(this);
