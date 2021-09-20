(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.InfoWindow = Backbone.View.extend({

    el: 'body',

    template: HandlebarsTemplates['common/info_window_tpl'],
    templateDownload: HandlebarsTemplates['common/download_window_tpl'],

    events: {
      'click .btn-close' : 'close',
      'click .modal-background': 'close'
    },


    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
    },

    render: function(data, name) {
      var description = data.description || null;
      var source = data.source || null;
      var link = data.link || null;
      var links = data.linkArray || null;
      var name = name || null;

      this.infoWindow = this.template({
        'description': description,
        'source': source,
        'link': link,
        'links': links,
        'name': name
      });

      this.$el.append( this.infoWindow );
    },

    renderDownload: function(url, subDomainParams) {
      var terms_accepted = localStorage.getItem('terms_accepted');

      this.downloadWindow = this.templateDownload({
        'url': url,
        'user_logged': window.userlogged && window.userlogged == 'true' ? true : false,
        'terms_accepted': terms_accepted && terms_accepted == 'true' ? true : false,
      });

      this.$el.append( this.downloadWindow );

      $('.theme-color').css({'color': subDomainParams.color});
      $('.theme-bg-color').css({'background-color': subDomainParams.color});

      $('#terms-and-conditions').on('change', this.terms_accepted);
    },

    terms_accepted: function(e) {
      var accepted = $('#terms-and-conditions').prop('checked');

      localStorage.setItem('terms_accepted', accepted);
      $('.btn-download-infowindow').toggleClass('-disabled', !accepted)
    },

    close: function() {
      $('.m-modal-window').remove();
    },

    toogleState: function() {
      this.$el.toggleClass('has-no-scroll');
      $('html').toggleClass('has-no-scroll');
    }

  });

})(this);
