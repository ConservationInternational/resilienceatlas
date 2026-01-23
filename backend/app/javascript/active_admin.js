// Import and start Rails UJS for ActiveAdmin
import Rails from "@rails/ujs"
Rails.start()

console.log('[ActiveAdmin] JavaScript module loaded');

// Import admin JavaScript modules (pinned via importmap)
import "admin/json_editor"
import "admin/select_dependency"
import "admin/checkbox_dependency"
import "admin/has_many_collapsable"
import "admin/globalize_translations"
import "admin/input_functions"

// Load ActiveAdmin core assets using Sprockets (these are not available as ES6 modules)
//= require active_admin/base
//= require active_admin/sortable
//= require trix
//= require activeadmin_addons/all
//= require_tree ./utils

// ActiveAdmin Globalize Translations support
// Custom replacement for activeadmin-globalize gem
// Using event delegation to handle clicks on translation tabs
document.addEventListener('click', function(e) {
  // Check if clicked element is a translation tab link
  var link = e.target.closest('.activeadmin-translations ul a');
  if (!link) return;
  
  console.log('[ActiveAdmin] Translation tab clicked:', link.getAttribute('href'));
  // Prevent navigation
  e.preventDefault();
  e.stopPropagation();
  
  var container = link.closest('.activeadmin-translations');
  if (!container) return;
  
  var href = link.getAttribute('href');
  if (!href || !href.startsWith('.locale-')) return;
  
  var targetClass = href.replace('.', '');
  
  // Update active tab
  var allTabs = container.querySelectorAll('ul a');
  allTabs.forEach(function(t) {
    t.classList.remove('active');
    if (t.parentElement) t.parentElement.classList.remove('active');
  });
  link.classList.add('active');
  if (link.parentElement) link.parentElement.classList.add('active');
  
  // Show/hide fieldsets
  var fieldsets = container.querySelectorAll('fieldset.locale');
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
}, true);

// Initialize first visible tab on page load
function initializeDefaultTab() {
  var containers = document.querySelectorAll('.activeadmin-translations');
  containers.forEach(function(container) {
    if (container.dataset.tabInitialized) return;
    container.dataset.tabInitialized = 'true';
    
    var defaultTab = container.querySelector('ul a.default') || container.querySelector('ul a');
    if (defaultTab) {
      defaultTab.click();
    }
  });
}

// Run on various page load events
document.addEventListener('DOMContentLoaded', initializeDefaultTab);
document.addEventListener('turbolinks:load', initializeDefaultTab);
document.addEventListener('turbo:load', initializeDefaultTab);

// Also run immediately if document is already loaded
if (document.readyState !== 'loading') {
  setTimeout(initializeDefaultTab, 100);
}