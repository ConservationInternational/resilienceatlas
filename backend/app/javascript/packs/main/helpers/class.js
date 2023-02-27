(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Helper = root.app.Helper || {};

  /**
   * Helper function to correctly set up the prototype chain for subclasses.
   * Similar to `goog.inherits`, but uses a hash of prototype properties and
   * class properties to be extended.
   * @param {Object} attributes
   */
  root.app.Helper.Class = function(attributes) {
    this.initialize.apply(this, arguments);
  };

  _.extend(root.app.Helper.Class.prototype, {});

  /**
   * Using Backbone Helper
   * https://github.com/jashkenas/backbone/blob/master/backbone.js#L1821
   * @type {Object}
   */
  root.app.Helper.Class.extend = Backbone.View.extend;

})(this);
