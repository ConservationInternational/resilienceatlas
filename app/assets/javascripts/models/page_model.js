define(['backbone'], function(Backbone) {

  'use strict';

  var PageModel = Backbone.Model.extend({

    defaults: {
      title: 'Empty page',
      params: {}
    }

  });

  return PageModel;

});
