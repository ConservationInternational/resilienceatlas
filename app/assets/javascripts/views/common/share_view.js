(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.Share = Backbone.View.extend({

    events: {
      'click .btn-close-modal': 'hide',
      'click .modal-background': 'hide',
      'click .btn-copy': 'copyUrl',
      'click .btn-social': '_socialClicked'
    },

    el: 'body',

    template: HandlebarsTemplates['common/share_tpl'],

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
      var url = window.location.href;
      var html = this.template({
        url: url,
        link: url,
        embed: url.replace('map', 'embed/map'),
        oembed: this.getOembedUrl()
      });

      this.$el.append(html);
      this.$el.find('.modal-container').removeClass('is-loading-share');
      this.afterRender();
    },

    afterRender: function() {
      $(document).foundation('tab', 'reflow');
    },

    getOembedUrl: function() {
      var utils = new app.View.Utils;
      var base64 = utils.toBase64(window.location.href);
      var url = window.location.origin + "/services/oembed/?url=" + base64;

      return url;
    },

    shareParams: function() {
      var mapState = window.location.search;
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
      var parentId = $parent[0].id;
      $url.select();

      if(parentId == 'share-link') {
        ga('send', 'event', 'Map', 'Share','Copy URL click');
      } else if(parentId == 'share-embed') {
        ga('send', 'event', 'Map', 'Share','Embed click');
      }

      try {
        var successful = document.execCommand('copy');
        $btn.html('copied');
      } catch(err) {}
    },

    _socialClicked: function(e) {
      var currClassList = e.currentTarget.classList;
      if (currClassList.contains('facebook')) {
        ga('send', 'event', 'Map', 'Share', 'facebook');
      } else if (currClassList.contains('twitter')) {
        ga('send', 'event', 'Map', 'Share', 'twitter');
      } else if (currClassList.contains('google')) {
        ga('send', 'event', 'Map', 'Share', 'google');
      }
    }

  });

})(this);
