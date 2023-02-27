(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Search = Backbone.View.extend({

    template: HandlebarsTemplates['common/search_tpl'],

    templateSuggestions: HandlebarsTemplates['common/search_suggestions_tpl'],

    defaults: {
      elContent: '.searchContent',
      elInput: '#searchMap',
      elSearchParent: '#searchBox',
      elSuggestions: '.search-suggestions',
      closeOnClick: true,
      triggerMap: true
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

      this.closeOnClick = this.options.closeOnClick;
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
      if(this.closeOnClick) {
        $('body').on('click', this.unHighlight.bind(this));
      }
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
        if(value && value.length > 0) {
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
      ga('send', 'event', 'Map', 'Search');

      if(this.closeOnClick) {
        this.$(this.elSuggestions +' li').removeClass('selected');
      }
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

        this.trigger('results', search);
        this.$(this.elSuggestions).html(this.templateSuggestions({data: search}));
        this.$(this.elContent).addClass('visible');
      }, this), 100);
    },

    clearSuggestions: function() {
      var $searchSuggestions = this.$(this.elSuggestions);
      $searchSuggestions.html('');
      this.$(this.elContent).removeClass('visible');
      this.trigger('results', []);
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

      var country = $target[0].title;
      if (typeof(country) !== 'undefined') {
        ga('send', 'event', 'Analysis', 'choose geography', country);
      }else{
        ga('send', 'event', 'Analysis', 'choose geography', 'ERR: Country undefined.');
      }

      if(area[0]) {
        var bbox = area[0].get('bbox');

        if (this.options.triggerMap) {
          Backbone.Events.trigger('map:set:fitbounds', bbox);
          Backbone.Events.trigger('map:set:mask', iso, 0.8, {
            query: 'select * from gadm28_adm0',
            tableName: 'gadm28_adm0'
          });
        }

        this.trigger('selected', iso, area[0].get('name'), bbox);
        this.setSelected(area[0]);
      }

      if(this.closeOnClick) {
        this.unHighlight();
      } else {
        this.$(this.elSuggestions +' li').removeClass('selected');
        $target.addClass('selected');
      }
    },

    setSelected: function(area) {
      var searchCollection = _.clone(this.searchCollection);

      _.map(searchCollection.models, function(model){
        var active = false;

        if(model.get('iso') === area.get('iso')) {
          active = true;
        }
        model.set({selected: active});
      });

      this.searchCollection.reset(searchCollection.models);
    }

  });

})(this);
