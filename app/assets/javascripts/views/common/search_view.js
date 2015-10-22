(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Search = Backbone.View.extend({

    template: HandlebarsTemplates['common/search_tpl'],

    templateSuggestions: HandlebarsTemplates['common/search_suggestions_tpl'],

    defaults: {
      elContent: '.searchContent',
      elInput: '.searchMap',
      elSearchParent: '#searchBox',
      elSuggestions: '.search-suggestions'
    },

    initialize: function(settings) {
      var self = this;
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      this.searchCollection = new root.app.Collection.Search();
      this.elContent = this.options.elContent;
      this.elInput = this.options.elInput;
      this.elSearchParent = this.options.elSearchParent;
      this.elSuggestions = this.options.elSuggestions;

      this.setEvents();
      this.getData();
    },

    setEvents: function() {
      this.events = {};
      this.events['keyup ' + this.elInput] = 'onSearch';
      this.events['focus ' + this.elInput] = 'highlight';
      this.events['keydown ' + this.elInput] = 'highlightResultsBox';
      this.events['click .search-area'] = 'searchArea';

      this.delegateEvents();
    },

    setListeners: function() {
      $('body').on('click', this.unHighlight.bind(this));
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
      this.$(this.elSuggestions +' li').removeClass('selected');
    },

    unHighlight: function(ev) {
      var $target = ev ? $(ev.target) : null;
      var id = null

      if($target) {
        id = $target.closest(this.elSearchParent).attr('id');
      }

      if(!id) {
        this.unFocus();
      }
    },

    unFocus: function() {
      var $input = this.$(this.elInput);
      $input.removeClass('focus');
      $input.blur();
      this.clearSearch();
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
            item.selected = item.selected || false;
            return item;
          }
        });

        this.$(this.elSuggestions).html(this.templateSuggestions({data: search}));
        this.$(this.elContent).addClass('visible');
      }, this), 100);
    },

    clearSuggestions: function() {
      var $searchSuggestions = this.$(this.elSuggestions);
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

    searchArea: function(ev) {
      ev.preventDefault();
      var $target = $(ev.currentTarget);
      var iso = $target.data('iso');
      var area = this.searchCollection.where({ iso: iso });

      if(area[0]) {
        var bbox = area[0].get('bbox');

        Backbone.Events.trigger('map:set:fitbounds', bbox);
        Backbone.Events.trigger('map:set:mask', iso, 0.8, {
          query: 'select * from grpcountries_250k_polygon',
          tableName: 'grpcountries_250k_polygon'
        });

        this.trigger('selected', iso);
        this.setSelected(area[0]);
      }

      this.unHighlight();
    },

    setSelected: function(area) {
      var searchCollection = _.clone(this.searchCollection);

      _.map(searchCollection.models, function(model){
        var active = false;

        if(model.get('iso') === area.get('iso')) {
          console.log('set true');
          active = true;
        }
        model.set({selected: active});
      });

      this.searchCollection.reset(searchCollection.models);
    }

  });

})(this);
