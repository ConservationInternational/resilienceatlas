define([
  'backbone',
  'underscore',
  'handlebars',
  'moment',
  'lib/utils',
  'collections/search_collection',  
  'text!templates/map/search_tpl.handlebars',
  'text!data/upper_lower_categories.json'
], function(Backbone, _, Handlebars, moment, utils, SearchCollection, TPL, CategoriesJSON) {

  'use strict';

  var SearchView = Backbone.View.extend({

    events: {
      'keyup #search': 'onSearch',
      'click .selector-category': 'toggleCategory',
      'click .btn-clear': 'clearSearch',
      'click .letter-filter li': 'filterByCharacter'
    },

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      var categoriesData = JSON.parse(CategoriesJSON);
      this.options = _.extend(this.defaults, options);

      this.categories = new SearchCollection(categoriesData, { parse: true });

      var $TPL = $(TPL);
      var TPLSearch = $TPL.filter('#search-tpl').html();
      var TPLResults = $TPL.filter('#search-results-tpl').html();
      var TPLSuggestions = $TPL.filter('#search-suggestions-tpl').html();

      this.tpl = Handlebars.compile(TPLSearch);
      this.tplResults = Handlebars.compile(TPLResults);
      this.tplSuggestions = Handlebars.compile(TPLSuggestions);

      this.render();
      this.setListeners();
    },

    setListeners: function() {
      Backbone.Events.on('search:show', this.show, this);
      Backbone.Events.on('search:hide', this.hide, this);
    },

    render: function() {
      this.$el.html(this.tpl({aplhabet: this.generateAlphaFilter()}));

      this.getUpperTier();
    },

    show: function() {
      this.$el.addClass('visible');
    },

    hide: function() {
      this.$el.removeClass('visible');
    },

    generateAlphaFilter: function() {
      var alphabet = "abcdefghijklmnopqrstuvwxyz".split('');
      var categories = this.categories.toJSON();
      var groupedResults = _.groupBy(categories, function(cat) {
        return cat.name.substring(0,1).toLowerCase();
      })
      var filteredAlphabet = [];
      var active = false;

      _.each(alphabet, function(a) {
        if(groupedResults[a] && groupedResults[a].length >= 1) {
          active = true;
        } else {
          active = false;
        }
        filteredAlphabet.push({
          value: a, 
          active: active
        });
      });

      return filteredAlphabet;
    },

    getUpperTier: function() {
      var upperTier = this.categories.getByCategory('Upper Tier');
      this.$('.search-result').html(this.tplResults({data: upperTier}));
      this.$el.find('.search-selector').removeClass('search-lower-tier');
    }, 

    getLowerTier: function(character) {
      var lowerTier = this.categories.getByCategory('Lower Tier');

      if(!character) {
        character = 'a';
      }

      this.$('.letter-filter li').removeClass('selected');
      this.$('.letter-filter li[data-value="'+character+'"]').addClass('selected');

      lowerTier = _.filter(lowerTier, function(lower) {
        var firstChar = lower['name'].substring(0,1).toLowerCase();
        if(firstChar === character) {
          return lower;
        }
      });

      this.$('.search-result').html(this.tplResults({data: lowerTier}));
      this.$el.find('.search-selector').addClass('search-lower-tier');
    },

    toggleCategory: function(ev) {
      ev.preventDefault();
      ev.stopPropagation();
      var $ele = $(ev.currentTarget);
      var cat = $ele.data('category');

      this.$('.selector-category').removeClass('selected');
      $ele.addClass('selected');

      if(cat === 'upper-tier') {
        this.getUpperTier();
      } else if(cat === 'lower-tier') {
        this.getLowerTier();
      }
    },

    onSearch: function(ev) {
      var target = ev ? ev.currentTarget : '#search';
      var $ele = $(target);
      var $searchBox = this.$('.search-content');
      var value = $ele.val();

      if(value.length > 0) {
        $searchBox.addClass('searching');
        this.showSuggestions(value);
      } else {
        $searchBox.removeClass('searching');
        this.clearSuggestions();
      }
    },

    clearSearch: function() {
      var $input = this.$('#search');
      $input.val('');
      this.onSearch();
    },

    clearSuggestions: function() {
      var $searchSuggestions = this.$('.search-suggestions');
      $searchSuggestions.html('');
    },

    filterByCharacter: function(ev) {
      ev.preventDefault();
      ev.stopPropagation();
      var $ele = $(ev.currentTarget);
      var character = $ele.data('value');

      if($ele.hasClass('active')) {
        this.getLowerTier(character);
      }
    },

    showSuggestions: function(text) {
      var search = this.categories.toJSON();

      if(this.searchTimer) {
        clearTimeout(this.timer);
      }
      this.searchTimer = setTimeout(_.bind(function() {
        search = _.filter(search, function(item) {
          var name = item['name'].toLowerCase().replace(/-/gi, ' ');
          var index = name.indexOf(text);
          if(index >= 0) {
            var start = item.name.substring(0, index);
            var substr = item.name.substring(index, index+text.length);
            var end = item.name.substring(index+text.length);
            item.title = item.name;
            item.name = start + '<span>' + substr + '</span>' + end;
            return item;
          }
        });
        this.$('.search-suggestions').html(this.tplSuggestions({data: search}));
      }, this), 100);
    }
  });

  return SearchView;
});
