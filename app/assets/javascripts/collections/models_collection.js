(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  var INDICATOR_VALUES = [1/9, 1/7, 1/5, 1/3, 1, 3, 5, 7, 9];
  var INDICATOR_HUMAN_READABLE_VALUES = ['1/9', '1/7', '1/5', '1/3', '1', '3', '5', '7', '9'];
  var INDICATOR_VALUE_DESC=['Extremely', 'Very', 'Strongly', 'Moderate', 'Equally', 'Moderate', 'Strongly', 'Very', 'Extremely'];

  root.app.Collection.Models = Backbone.Collection.extend({
    url: function() {
      return '/api/models?site_scope=' + this.siteScopeId;
    },

    initialize: function (models, options) {
      this.siteScopeId = options.siteScopeId;
    },

    parse: function(response) {
      return response.data.map(function(model) {
        return {
          id: model.id,
          name: model.attributes.name,
          description: model.attributes.description,
          source: model.attributes.source,
          tableName: model.attributes.table_name,
          indicators: model.relationships && model.relationships.indicators && model.relationships.indicators.data
            ? model.relationships.indicators.data.map(function(indicator) {
                var ind = response.included.find(function(inc) {
                  return inc.type === 'indicators' && inc.id === indicator.id;
                });

                var category = response.included.find(function(inc) {
                  return inc.type === 'categories' && inc.id === ind.relationships.category.data.id;
                });

                return {
                  id: indicator.id,
                  name: ind.attributes.name,
                  slug: ind.attributes.slug,
                  category: category.attributes.name,
                  version: ind.attributes.version,
                  position: ind.attributes.position,
                  column: ind.attributes.column_name,
                  operation: ind.attributes.operation,
                  value: 1,
                  indexableValue: this.getIndexableIndicatorValue(1),
                  humanReadableValue: this.getHumanReadableIndicatorValue(1)
                };
              }.bind(this))
            : []
        };
      }.bind(this));
    },

    /**
     * Return the min and max of the indexable indicator
     * values
     * @returns {number[]} Value range
     */
    getIndexableIndicatorValueRange: function () {
      return [0, INDICATOR_VALUES.length - 1];
    },

    /**
     * Return the value of an indicator as an index number
     * between 0 and 8 (inclusive)
     * @param {number} value Original value
     * @returns {number} Index number
     */
    getIndexableIndicatorValue: function(value) {
      var index = INDICATOR_VALUES.indexOf(value);
      if (value === null || index === -1) {
        return null;
      } else {
        return index;
      }
    },

    /**
     * Return the value of an indicator in a fraction
     * format
     * @param {number} value Original value
     * @returns {string} Human readable value
     */
    getHumanReadableIndicatorValue: function(value) {
      var index = this.getIndexableIndicatorValue(value);
      if (index === null) {
        return '';
      } else {
        return INDICATOR_HUMAN_READABLE_VALUES[index];
      }
    },

    /**
     * Return the indicator value associated with the
     * index number
     * @param {number} indexValue Index number
     * @returns {number} Original value
     */
    getRealIndicatorValueFromIndex: function(indexValue) {
      return INDICATOR_VALUES[indexValue];
    },

    /**
     * Return the indicator's human readable value
     * (fractional number) associated with the index number
     * @param {number} indexValue Index number
     * @returns {string} Human readable value
     */
    getHumanReadableIndicatorValueFromIndex: function(indexValue) {
      return INDICATOR_HUMAN_READABLE_VALUES[indexValue];
    },

    /**
     * Return the indicator's value description associated
     * with the index number
     * @param {number} indexValue Index number
     * @returns {string} Description of the value
     */
    getValueDescriptionFromIndex: function(indexValue) {
      return INDICATOR_VALUE_DESC[indexValue];
    }
  });

})(this);
