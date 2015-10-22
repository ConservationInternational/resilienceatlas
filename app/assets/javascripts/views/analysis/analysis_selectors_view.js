(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.analysisSelectors = Backbone.View.extend({

    events: {
      'click .category': 'selectCategory'
    },

    el: '#analysisSelectorsView',

    template: HandlebarsTemplates['analysis/analysis_selectors_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.state = new Backbone.Model({
        category: null,
        iso: null
      });

      this.setListeners();
      this.getData();
    },

    setListeners: function() {
      this.listenTo(this.state, 'change', this.checkParams);
    },

    checkParams: function() {
      if(this.state.get('category') && this.state.get('iso')) {

      } else {

      }

    },

    getData: function() {
      var self = this;

      this.analysisCollection = new root.app.Collection.Analysis();
      this.analysisCollection.fetch().done(function() {
        self.render();
      });
    },

    getCategories: function() {
      var data = this.data;
      var categories = [];

      _.each(data, function(category) {
        categories.push({
          name: category.category_name,
          slug: category.category_slug
        })
      });

      return categories;
    },

    render: function() {
      this.data = this.analysisCollection.toJSON();

      this.$el.html(this.template({
        categories: this.getCategories()
      }));

      if(!this.searchView) {
        this.searchView = new root.app.View.Search({
          el: '#analysisSelectorsView',
          elContent: '.analysisSearchContent',
          elInput: '.searchAnalysis',
          elSearchParent: '#analysisSelectorsView',
          closeOnClick: false
        });

        this.listenTo(this.searchView, 'selected', this.selectIso);
      }

      this.$el.addClass('visible');
    },

    selectIso: function(iso) {
      if(iso) {
        this.state.set('iso', iso);
        this.$('.searchAnalysisBox').addClass('selected');
      }
    },

    selectCategory: function(ev) {
      var $target = $(ev.currentTarget);
      var slug = $target.data('slug');

      if(slug) {
        this.state.set('category', slug);
        $target.closest('.selector-box').addClass('selected');
        $target.closest('.selector-box').find('ul li').removeClass('selected');
        $target.addClass('selected');
      }
    }

  });

})(this);
