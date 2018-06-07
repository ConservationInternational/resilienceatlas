(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.analysisSelectors = Backbone.View.extend({

    events: {
      'click .category': 'selectCategory',
      'click .btn-analyze': 'startAnalyze'
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
        this.$('.analyze').removeClass('disabled');
      } else {
        this.$('.analyze').addClass('disabled');
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

        this.listenTo(this.searchView, 'selected', this.selectIsoAndCountry);
        this.listenTo(this.searchView, 'results', this.showingResults);
      }
    },

    selectIsoAndCountry: function(iso, country) {
      if(iso && country) {
        this.state.set({
          'iso': iso,
          'country': country
        });
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

      ga('send', 'event', 'Analysis', 'choose theme', slug);
    },

    closeAnalysis: function() {
      if(this.analyzeView) {
        this.analyzeView.hideAnalysis();
      }
    },

    renderAnalyzeContainer: function() {
      $('#analysisView').html('<div id="analysisData"></div>');
    },

    startAnalyze: function() {
      if(this.analyzeView) {
        this.analyzeView.remove();
      }

      this.renderAnalyzeContainer();

      var collection = this.analysisCollection.toJSON();
      var data = _.where(collection, {
        category_slug: this.state.get('category')
      });

      if(data[0]) {
        this.analyzeView = new root.app.View.AnalysisPageView({
          category: this.state.get('category'),
          iso: this.state.get('iso'),
          country: this.state.get('country'),
          el: '#analysisData',
          data: data[0]
        });
      }

      ga('send', 'event', 'Analysis', 'start analysis');
    },

    showingResults: function(results) {
      if(results.length > 5) {
        this.$el.addClass('highlight');
      } else {
        this.$el.removeClass('highlight');
      }
    },

    /**
     * Destroy the view
     * Same as remove but without removing the node
     */
    destroy() {
      this.closeAnalysis();
      if (this.analyzeView) {
        this.analyzeView.remove();
      }
      this.$el.html('');
    }

  });

})(this);
