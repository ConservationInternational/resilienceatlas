(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.Collection = root.app.Collection || {};

  var MODELS = [
    {
      name: 'Model 1',
      indicators: [
        {
          name: 'Soil pH',
          value: 1
        },
        {
          name: 'Organic carbon content (fine earth fraction)',
          value: 1
        },
        {
          name: 'Nitrogen (total organic nitrogen extractable by wet oxydation)',
          value: 1
        },
        {
          name: 'Phosphorus (total)',
          value: 1
        },
        {
          name: 'Potassium (extractable by Mehlich 3)',
          value: 1
        }
      ]
    },
    {
      name: 'Model 2',
      indicators: [
        {
          name: 'Soil pH',
          value: 1
        },
        {
          name: 'Organic carbon content (fine earth fraction)',
          value: 1
        },
        {
          name: 'Nitrogen (total organic nitrogen extractable by wet oxydation)',
          value: 1
        },
        {
          name: 'Phosphorus (total)',
          value: 1
        },
        {
          name: 'Potassium (extractable by Mehlich 3)',
          value: 1
        }
      ]
    }
  ];

  var INDICATOR_VALUES = [1/9, 1/7, 1/5, 1/3, 1, 3, 5, 7, 9];
  var INDICATOR_HUMAN_READABLE_VALUES = ['1/9', '1/7', '1/5', '1/3', '1', '3', '5', '7', '9'];
  var INDICATOR_VALUE_DESC=['Extremely', 'Very', 'Strongly', 'Moderate', 'Equally', 'Moderate', 'Strongly', 'Very', 'Extremely'];

  root.app.Collection.Models = Backbone.Collection.extend({
    fetch: function() {
      var deferred = $.Deferred();

      var data = MODELS.map(function(model) {
        return _.extend({}, model, {
          indicators: model.indicators.map(function(indicator) {
            return _.extend({}, indicator, {
              indexableValue: this.getIndexableIndicatorValue(indicator.value),
              humanReadableValue: this.getHumanReadableIndicatorValue(indicator.value)
            });
          }.bind(this))
        });
      }.bind(this));


      this.set(data);
      deferred.resolve(data);
      return deferred;
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
