// JSON Editor functionality for ActiveAdmin forms
// Provides pretty-printing, syntax validation, and formatting for JSON text areas

console.log('[JSON Editor] Script loaded');

(function() {
  'use strict';

  // Configuration for JSON editor textareas - match by class or name attribute
  const JSON_FIELD_SELECTORS = [
    'textarea.json-editor-textarea',
    'textarea[name*="[layer_config]"]',
    'textarea[name*="[interaction_config]"]',
    'textarea[name*="[analysis_body]"]',
    'textarea[name*="[analysis_query]"]'
  ];

  // Simple syntax highlighting colors
  const SYNTAX_COLORS = {
    key: '#881391',      // Purple for keys
    string: '#1a1aa6',   // Blue for string values
    number: '#098658',   // Green for numbers
    boolean: '#0000ff',  // Blue for booleans
    null: '#808080',     // Gray for null
    bracket: '#000000'   // Black for brackets
  };

  // Initialize JSON editors on page load
  function initJsonEditors() {
    console.log('[JSON Editor] initJsonEditors called');
    const selectors = JSON_FIELD_SELECTORS.join(', ');
    const textareas = document.querySelectorAll(selectors);
    console.log('[JSON Editor] Found', textareas.length, 'textareas matching:', selectors);
    
    textareas.forEach(function(textarea) {
      if (textarea.dataset.jsonEditorInitialized) return;
      textarea.dataset.jsonEditorInitialized = 'true';
      
      setupJsonEditor(textarea);
    });
  }

  // Set up a single JSON editor
  function setupJsonEditor(textarea) {
    // Add CSS class for styling
    textarea.classList.add('json-editor-textarea');
    
    // Create wrapper container
    const wrapper = document.createElement('div');
    wrapper.className = 'json-editor-wrapper';
    textarea.parentNode.insertBefore(wrapper, textarea);
    wrapper.appendChild(textarea);
    
    // Create toolbar
    const toolbar = document.createElement('div');
    toolbar.className = 'json-editor-toolbar';
    
    // Format button
    const formatBtn = document.createElement('button');
    formatBtn.type = 'button';
    formatBtn.className = 'json-editor-btn json-editor-format-btn';
    formatBtn.textContent = 'Format JSON';
    formatBtn.addEventListener('click', function(e) {
      e.preventDefault();
      formatJson(textarea);
    });
    toolbar.appendChild(formatBtn);
    
    // Minify button
    const minifyBtn = document.createElement('button');
    minifyBtn.type = 'button';
    minifyBtn.className = 'json-editor-btn json-editor-minify-btn';
    minifyBtn.textContent = 'Minify';
    minifyBtn.addEventListener('click', function(e) {
      e.preventDefault();
      minifyJson(textarea);
    });
    toolbar.appendChild(minifyBtn);
    
    // Validate button
    const validateBtn = document.createElement('button');
    validateBtn.type = 'button';
    validateBtn.className = 'json-editor-btn json-editor-validate-btn';
    validateBtn.textContent = 'Validate';
    validateBtn.addEventListener('click', function(e) {
      e.preventDefault();
      validateJson(textarea);
    });
    toolbar.appendChild(validateBtn);
    
    // Status indicator
    const statusIndicator = document.createElement('span');
    statusIndicator.className = 'json-editor-status';
    toolbar.appendChild(statusIndicator);
    
    wrapper.insertBefore(toolbar, textarea);
    
    // Create preview panel for syntax highlighting
    const preview = document.createElement('div');
    preview.className = 'json-editor-preview';
    preview.style.display = 'none';
    wrapper.appendChild(preview);
    
    // Add toggle for preview
    const previewToggle = document.createElement('button');
    previewToggle.type = 'button';
    previewToggle.className = 'json-editor-btn json-editor-preview-toggle';
    previewToggle.textContent = 'Toggle Preview';
    previewToggle.addEventListener('click', function(e) {
      e.preventDefault();
      togglePreview(textarea, preview);
    });
    toolbar.appendChild(previewToggle);
    
    // Store references
    textarea.jsonEditorStatus = statusIndicator;
    textarea.jsonEditorPreview = preview;
    
    // Auto-format on load if content exists
    if (textarea.value.trim()) {
      formatJson(textarea, true); // silent mode - don't show success message
      updatePreview(textarea, preview);
    }
    
    // Add input event listener for real-time validation
    textarea.addEventListener('input', debounce(function() {
      validateJson(textarea, true); // silent mode
      updatePreview(textarea, preview);
    }, 500));
    
    // Initial validation
    if (textarea.value.trim()) {
      validateJson(textarea, true);
    }
  }

  // Format JSON with pretty-printing
  function formatJson(textarea, silent) {
    const value = textarea.value.trim();
    if (!value) {
      if (!silent) showStatus(textarea, 'Empty input', 'warning');
      return;
    }
    
    try {
      const parsed = JSON.parse(value);
      const formatted = JSON.stringify(parsed, null, 2);
      textarea.value = formatted;
      
      // Trigger change event for form validation
      textarea.dispatchEvent(new Event('change', { bubbles: true }));
      
      if (!silent) showStatus(textarea, 'JSON formatted successfully', 'success');
    } catch (e) {
      showStatus(textarea, 'Invalid JSON: ' + e.message, 'error');
    }
  }

  // Minify JSON
  function minifyJson(textarea) {
    const value = textarea.value.trim();
    if (!value) {
      showStatus(textarea, 'Empty input', 'warning');
      return;
    }
    
    try {
      const parsed = JSON.parse(value);
      const minified = JSON.stringify(parsed);
      textarea.value = minified;
      
      // Trigger change event for form validation
      textarea.dispatchEvent(new Event('change', { bubbles: true }));
      
      showStatus(textarea, 'JSON minified', 'success');
    } catch (e) {
      showStatus(textarea, 'Invalid JSON: ' + e.message, 'error');
    }
  }

  // Validate JSON
  function validateJson(textarea, silent) {
    const value = textarea.value.trim();
    if (!value) {
      if (!silent) showStatus(textarea, 'Empty input - JSON is optional', 'warning');
      textarea.classList.remove('json-valid', 'json-invalid');
      return true;
    }
    
    try {
      JSON.parse(value);
      textarea.classList.add('json-valid');
      textarea.classList.remove('json-invalid');
      if (!silent) showStatus(textarea, 'Valid JSON', 'success');
      return true;
    } catch (e) {
      textarea.classList.add('json-invalid');
      textarea.classList.remove('json-valid');
      if (!silent) showStatus(textarea, 'Invalid JSON: ' + e.message, 'error');
      return false;
    }
  }

  // Toggle preview panel
  function togglePreview(textarea, preview) {
    if (preview.style.display === 'none') {
      preview.style.display = 'block';
      textarea.style.display = 'none';
      updatePreview(textarea, preview);
    } else {
      preview.style.display = 'none';
      textarea.style.display = 'block';
    }
  }

  // Update syntax-highlighted preview
  function updatePreview(textarea, preview) {
    const value = textarea.value.trim();
    if (!value) {
      preview.innerHTML = '<span class="json-empty">Empty</span>';
      return;
    }
    
    try {
      const parsed = JSON.parse(value);
      const formatted = JSON.stringify(parsed, null, 2);
      preview.innerHTML = syntaxHighlight(formatted);
    } catch (e) {
      preview.innerHTML = '<span class="json-error">Invalid JSON: ' + escapeHtml(e.message) + '</span><pre>' + escapeHtml(value) + '</pre>';
    }
  }

  // Syntax highlighting for JSON
  function syntaxHighlight(json) {
    // Escape HTML first
    json = escapeHtml(json);
    
    // Apply syntax highlighting
    return json.replace(
      /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
      function(match) {
        let cls = 'json-number';
        if (/^"/.test(match)) {
          if (/:$/.test(match)) {
            cls = 'json-key';
          } else {
            cls = 'json-string';
          }
        } else if (/true|false/.test(match)) {
          cls = 'json-boolean';
        } else if (/null/.test(match)) {
          cls = 'json-null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
      }
    );
  }

  // Show status message
  function showStatus(textarea, message, type) {
    const status = textarea.jsonEditorStatus;
    if (!status) return;
    
    status.textContent = message;
    status.className = 'json-editor-status json-editor-status-' + type;
    
    // Auto-clear success/warning messages after 3 seconds
    if (type !== 'error') {
      setTimeout(function() {
        if (status.textContent === message) {
          status.textContent = '';
          status.className = 'json-editor-status';
        }
      }, 3000);
    }
  }

  // Utility: Escape HTML
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Utility: Debounce function
  function debounce(func, wait) {
    let timeout;
    return function executedFunction() {
      const context = this;
      const args = arguments;
      const later = function() {
        timeout = null;
        func.apply(context, args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // Initialize on various page load events
  document.addEventListener('DOMContentLoaded', initJsonEditors);
  document.addEventListener('turbolinks:load', initJsonEditors);
  document.addEventListener('turbo:load', initJsonEditors);
  
  // Also initialize after a delay for dynamic content
  if (document.readyState !== 'loading') {
    setTimeout(initJsonEditors, 100);
  }
  
  // Re-initialize when has_many fields are added
  document.addEventListener('has_many_add:after', function() {
    setTimeout(initJsonEditors, 100);
  });

})();
