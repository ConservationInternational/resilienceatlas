define([], function() {

  'use strict';

  /**
   * Extending String.prototype
   * How to use: '%1 beer'.format(2)
   * Returns '2 beers'
   */
  if (!String.prototype.format) {
    String.prototype.format = function() {
      var args = [].slice.call(arguments),
        result = this.slice(),
        regexp;
      for (var i = args.length; i--;) {
        regexp = new RegExp('%' + (i + 1), 'g');
        result = result.replace(regexp, args[i]);
      }
      return result;
    };
  }

});
