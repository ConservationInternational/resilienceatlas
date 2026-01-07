// Active Admin Globalize Translations JavaScript
// Custom replacement for activeadmin-globalize gem

(function() {
  function initializeTranslations() {
    var containers = document.querySelectorAll('.activeadmin-translations');
    
    containers.forEach(function(container) {
      if (container.dataset.initialized) return;
      container.dataset.initialized = 'true';
      
      var tabList = container.querySelector('ul.available-locales, ul.locale-selector');
      if (!tabList) return;
      
      var tabs = tabList.querySelectorAll('li a, li.translation-tab a');
      var fieldsets = container.querySelectorAll('fieldset.locale');
      
      // Handle tab clicks
      tabs.forEach(function(tab) {
        tab.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();
          
          var targetClass = tab.getAttribute('href').replace('.', '');
          
          // Update active tab
          tabs.forEach(function(t) {
            t.classList.remove('active');
            t.parentElement.classList.remove('active');
          });
          tab.classList.add('active');
          tab.parentElement.classList.add('active');
          
          // Show/hide fieldsets
          fieldsets.forEach(function(fieldset) {
            if (fieldset.classList.contains(targetClass)) {
              fieldset.classList.add('active');
              fieldset.style.display = 'block';
            } else {
              fieldset.classList.remove('active');
              fieldset.style.display = 'none';
            }
          });
          
          return false;
        });
      });
      
      // Click the default tab to initialize
      var defaultTab = tabList.querySelector('a.default') || tabs[0];
      if (defaultTab) {
        defaultTab.click();
      }
    });
    
    // Handle inline translation triggers (for show pages)
    var triggers = document.querySelectorAll('.ui-translation-trigger');
    triggers.forEach(function(trigger) {
      if (trigger.dataset.initialized) return;
      trigger.dataset.initialized = 'true';
      
      trigger.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var locale = trigger.dataset.locale;
        var container = trigger.closest('td');
        if (!container) return;
        
        // Update active trigger
        container.querySelectorAll('.ui-translation-trigger').forEach(function(t) {
          t.classList.remove('active');
        });
        trigger.classList.add('active');
        
        // Show/hide translation spans
        container.querySelectorAll('.field-translation').forEach(function(span) {
          if (span.classList.contains('locale-' + locale)) {
            span.classList.remove('hidden');
          } else {
            span.classList.add('hidden');
          }
        });
        
        return false;
      });
    });
  }

  // Initialize on DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeTranslations);
  } else {
    initializeTranslations();
  }

  // Re-initialize when has_many adds new items (ActiveAdmin event)
  document.addEventListener('has_many_add:after', function() {
    setTimeout(initializeTranslations, 50);
  });
})();
