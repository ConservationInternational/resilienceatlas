(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Share = Backbone.View.extend({

    events: {
      'click .btn-close-modal': 'hide',
      'click .modal-background': 'hide',
      'click .btn-copy': 'copyUrl'
    },

    el: 'body',

    template: HandlebarsTemplates['share_tpl'],

    initialize: function(settings) {
      var options = settings && settings.options ? settings.options : settings;
      this.options = _.extend(this.defaults, options);

      // this.map = options.map;
      // this.layers = options.layers;
      this.setListeners();
    },

    setListeners: function() {
      Backbone.Events.on('share:show', this.show, this);
      Backbone.Events.on('share:hide', this.hide, this);
    },

    render: function() {
      // var self = this;

      // $.when(this.shareParams()).done(function(res) {
      //   var url = 'http://' + window.location.hostname + ':3000/embed' + res.uid ;

      //   var html = self.template({
      //     url: url,
      //     link: url.replace('embed', 'map')
      //   });

      //   self.$el.append(html);
      //   self.$el.find('.modal-container').removeClass('is-loading-share');
      //   self.afterRender();
      // });

      var url = window.location.href;
      var html = this.template({
        url: url,
        link: encodeURIComponent(url.replace('embed', ''))
      });

      this.$el.append(html);
      this.$el.find('.modal-container').removeClass('is-loading-share');
      this.afterRender();
    },

    afterRender: function() {
      $(document).foundation('tab', 'reflow');
    },

    shareParams: function() {
      // var mapState = this.map.getMapState();
      // var layersState = this.layers.getActiveLayers();

      // var activeLayers = [];

      // _.each(layersState, function(layer) {
      //   activeLayers.push(layer.slug);
      // });

      // mapState.layers = activeLayers;
      var mapState = window.location.search;
      console.log(mapState);
      var encodedParams = btoa(JSON.stringify(mapState));

      return $.ajax({
        url: '/api/share?body='+encodedParams,
        method: 'POST',
        headers: {
          'X-Csrf-Token': decodeURIComponent(this.getCookie('X-CSRF-Token')),
          'Accept': 'application/json; application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json'
        },
        error: function(xhr, textStatus) {
          console.warn(textStatus);
        }
      });
    },

    getParams: function(shareId) {
      return $.ajax({
        url: '/api/share/'+shareId,
        method: 'GET',
        error: function(xhr, textStatus) {
          console.warn(textStatus);
        }
      });
    },

    getCookie: function(cname) {
      var name = cname + '=';
      var ca = document.cookie.split(';');
      for(var i=0; i<ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1);
        if (c.indexOf(name) == 0) return c.substring(name.length,c.length);
      }
      return '';
    },

    show: function() {
      this.render();
    },

    hide: function() {
      this.$el.find('.m-modal-window').remove();
    },

    copyUrl: function() {
      var $parent = this.$el.find('.m-share .content.active');
      var $url = $parent.find('.url');
      var $btn = $parent.find('.btn-copy');

      $url.select();
      try {
        var successful = document.execCommand('copy');
        $btn.html('copied');
      } catch(err) {}
    }


  });

})(this);
