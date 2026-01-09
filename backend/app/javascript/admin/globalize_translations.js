// Active Admin Globalize Translations JavaScript
// Custom replacement for activeadmin-globalize gem

function initializeTranslations() {
  $('.activeadmin-translations').each(function() {
    var container = $(this);
    if (container.data('initialized')) return;
    container.data('initialized', true);
    
    var tabList = container.find('ul.available-locales, ul.locale-selector').first();
    if (!tabList.length) return;
    
    var tabs = tabList.find('li a, li.translation-tab a');
    var fieldsets = container.find('> fieldset.locale');
    
    // Handle tab clicks - prevent default navigation
    tabs.on('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var tab = $(this);
      var targetClass = tab.attr('href').replace('.', '');
      
      // Update active tab
      tabs.removeClass('active');
      tabs.parent().removeClass('active');
      tab.addClass('active');
      tab.parent().addClass('active');
      
      // Show/hide fieldsets using active class
      fieldsets.each(function() {
        var fieldset = $(this);
        if (fieldset.hasClass(targetClass)) {
          fieldset.addClass('active').show();
        } else {
          fieldset.removeClass('active').hide();
        }
      });
      
      return false;
    });
    
    // Click the default tab to initialize (the one with class 'default')
    var defaultTab = tabList.find('a.default').first();
    if (!defaultTab.length) {
      defaultTab = tabs.first();
    }
    if (defaultTab.length) {
      defaultTab.trigger('click');
    }
  });
  
  // Handle inline translation triggers (for show pages)
  $('.ui-translation-trigger').each(function() {
    var trigger = $(this);
    if (trigger.data('initialized')) return;
    trigger.data('initialized', true);
    
    trigger.on('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var locale = trigger.data('locale');
      var container = trigger.closest('td');
      if (!container.length) return;
      
      // Update active trigger
      container.find('.ui-translation-trigger').removeClass('active');
      trigger.addClass('active');
      
      // Show/hide translation spans
      container.find('.field-translation').each(function() {
        var span = $(this);
        if (span.hasClass('locale-' + locale)) {
          span.removeClass('hidden');
        } else {
          span.addClass('hidden');
        }
      });
      
      return false;
    });
  });
}

$(document).ready(initializeTranslations);

// Re-initialize when has_many adds new items
$(document).on('has_many_add:after', function() {
  setTimeout(initializeTranslations, 50);
});
