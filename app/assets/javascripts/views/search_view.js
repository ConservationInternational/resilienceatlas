(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Search = Backbone.View.extend({

    template: HandlebarsTemplates['search_tpl'],

    templateSuggestions: HandlebarsTemplates['search_suggestions_tpl'],

    defaults: {
    },

    elContent: '#searchContent',
    elInput: '#searchMap',

    events: {
      'keyup #searchMap': 'onSearch',
      'focus #searchMap': 'highlight',
      'keydown #searchMap': 'highlightResultsBox',
      'click .search-area': 'searchArea'
    },

    initialize: function(settings) {
      var self = this;
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.map = this.options.map;
      this.searchCollection = new root.app.Collection.Search();
      this.navigation = 0;
      this.getData();
    },

    setListeners: function() {
      Backbone.Events.on('search:clear', this.unFocus.bind(this));
      this.$el.on('click', this.unHighlight);
    },

    getData: function() {
      var self = this;

      $.when(this.searchCollection.getData()).then(function() {
        self.render();
        self.setListeners();
      });
    },

    render: function() {
      var data = [];

      this.$(this.elContent).html(this.template({ }));
    },

    onSearch: function(ev) {
      var target = ev ? ev.currentTarget : this.elInput;
      var $ele = $(target);
      var $searchBox = this.$('.search-content');
      var value = $ele.val();
      var key = ev && ev.keyCode ? ev.keyCode : 0;
      
      if(key !== 40 || key !== 38) {
        if(value.length > 0) {
          $searchBox.addClass('searching');
          this.showSuggestions(value);
        } else {
          $searchBox.removeClass('searching');
          this.clearSuggestions();
        }
      }
    },

    highlight: function(ev) {
      ev.preventDefault();
      ev.stopPropagation();

      this.$(this.elInput).addClass('focus');
      this.$('.search-suggestions li').removeClass('selected');
    },

    unHighlight: function(ev) {
      var $target = ev ? $(ev.target) : null;
      var id = null;

      if($target) {
        id = $target.closest('#searchBox').attr('id');
      }

      if(!id) {
        Backbone.Events.trigger('search:clear');
      }
    },

    unFocus: function() {
      var $input = this.$(this.elInput);
      $input.removeClass('focus');
      $input.blur();
      this.clearSearch();
      $('body').off('keydown', this.checkNavigation);
    },

    showSuggestions: function(text) {
      text = text.toLowerCase();
      var search = this.searchCollection.toJSON();

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
            item.iso = item.iso;
            item.name = start + '<span>' + substr + '</span>' + end;
            return item;
          }
        });

        this.$('.search-suggestions').html(this.templateSuggestions({data: search}));
        this.$(this.elContent).addClass('visible');
      }, this), 100);
    },

    clearSuggestions: function() {
      var $searchSuggestions = this.$('.search-suggestions');
      $searchSuggestions.html('');
      this.$(this.elContent).removeClass('visible');
    },

    clearSearch: function() {
      var $input = this.$(this.elInput);
      $input.val('');
      this.onSearch();
    },

    highlightResultsBox: function(ev) {      
      var key = ev.keyCode || 0;

      if(key === 27) {
        this.unHighlight();
      }
    },

    checkNavigation: function(ev) {
      var key = ev.keyCode || 0;
      var direction = '';

      if(key === 40 || key === 38) {
        ev.preventDefault();
        ev.stopPropagation();

        Backbone.Events.trigger('search:navigate', key);
      }
    },

    searchArea: function(ev) {
      ev.preventDefault();
      var $target = $(ev.currentTarget);
      var iso = $target.data('iso');
      var area = this.searchCollection.where({ iso: iso });

      if(area[0]) {
        var bbox = area[0].get('bbox');
        
        this.map.setBbox(bbox);
        this.map.setMaskLayer(iso, 0.8, {
          query: 'select * from grpcountries_250k_polygon',
          tableName: 'grpcountries_250k_polygon'
        });
      }
      this.unHighlight();
    }
  });

})(this);