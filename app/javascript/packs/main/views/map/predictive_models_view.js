(function(root) {

  'use strict';

  root.app = root.app || {};
  root.app.View = root.app.View || {};

  root.app.View.PredictiveModels = Backbone.View.extend({
    defaults: {},

    events: {
      'change .model-selector': 'onChangeModelSelector',
      // If we listen to the "input" event instead of the "change"
      // one, we can update the UI as the user is sliding
      'input .js-indicator-slider': 'onChangeIndicatorSlider',
      'mouseover .js-indicator-slider': 'onMouseoverIndicatorSlider',
      'mouseout .js-indicator-slider': 'onMouseoutIndicatorSlider',
      'change .js-indicator-toggle': 'onChangeIndicatorToggle',
      'click .js-apply': 'onClickApply',
      'click .js-reset': 'onClickReset'
    },

    template: HandlebarsTemplates['map/predictive_model_tpl'],

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);
      this.router = settings.router;

      this.setListeners();

      this.collection.fetch()
        .done(function() {
          // We restore the state of the predictive model
          // if present in the URL
          if (this.router.params.get('model')) {
            try {
              var serializedModel = JSON.parse(this.router.params.get('model'));
              var model = this.collection.findWhere({ name: serializedModel.name }).toJSON();
              this.model.set(model);

              for (var i = 0, j = serializedModel.values.length; i < j; i++) {
                var indicatorName = this.model.get('indicators')[i].name;
                var indicatorRealValue = this.collection.getRealIndicatorValueFromIndex(serializedModel.values[i]);
                var indicatorHumanReadableValue = this.collection.getHumanReadableIndicatorValueFromIndex(serializedModel.values[i]);

                this.updateModel(indicatorName, {
                  value: indicatorRealValue,
                  indexableValue: serializedModel.values[i],
                  humanReadableValue: indicatorHumanReadableValue
                })
              }

              Backbone.Events.trigger('map:show:model');
            } catch (e) {}
          }

          this.render();
        }.bind(this));
    },

    /**
     * Set the listeners that aren't attached
     * to a DOM node
     */
    setListeners: function() {
      this.listenTo(this.model, 'change:name', this.render.bind(this));
    },

    /**
     * Event handler executed when the user changes the
     * value of the model selector
     * @param {Event} e Event
     */
    onChangeModelSelector: function(e) {
      var modelName = e.target.selectedOptions[0].value;
      var model = this.collection.findWhere({ name: modelName }).toJSON();
      this.model.set(model);
      this.updateURL();
      Backbone.Events.trigger('map:show:model');
    },

    /**
     * Event handler executed when the user moves the
     * handle of the slider
     * @param {Event} e Event
     */
    onChangeIndicatorSlider: function(e) {
      /** @type {HTMLElement} input */
      var input = e.target;
      var indicatorName = input.getAttribute('data-indicator');
      var indicatorIndexValue = +input.value;
      var indicatorRealValue = this.collection.getRealIndicatorValueFromIndex(indicatorIndexValue);
      var indicatorHumanReadableValue = this.collection.getHumanReadableIndicatorValueFromIndex(indicatorIndexValue);
      var tooltip = input.parentElement.querySelector('.tooltip');
      var handleSize = 12;
      var percentage = ((indicatorIndexValue / this.collection.getIndexableIndicatorValueRange()[1]) * 100);

      // We update the human readable value next to the slider
      var textInput = input.closest('li').querySelector('.opacity-teller');
      textInput.value = indicatorHumanReadableValue;

      // We update the position of the slider's "runnable" track
      var runnableTrack = input.parentElement.querySelector('.opacity');
      runnableTrack.style.width = percentage + '%';

      // We update the content of the tooltip and its position
      tooltip.textContent = this.collection.getValueDescriptionFromIndex(indicatorIndexValue);
      tooltip.style.left = 'calc(' + percentage + '% - ' + ((percentage * handleSize) / 100) + 'px + ' + (handleSize / 2) + 'px)';

      // We update the state of the model
      this.updateModel(indicatorName, {
        value: indicatorRealValue,
        indexableValue: indicatorIndexValue,
        humanReadableValue: indicatorHumanReadableValue
      });
    },

    /**
     * Event handler executed when the user hovers
     * the slider
     * @param {Event} e Event
     */
    onMouseoverIndicatorSlider: function(e) {
      /** @type {HTMLElement} input */
      var input = e.target;
      var indicatorIndexValue = +input.value;
      var tooltip = input.parentElement.querySelector('.tooltip');
      var handleSize = 12;

      var percentage = ((indicatorIndexValue / this.collection.getIndexableIndicatorValueRange()[1]) * 100);
      tooltip.style.left = 'calc(' + percentage + '% - ' + ((percentage * handleSize) / 100) + 'px + ' + (handleSize / 2) + 'px)';
      tooltip.textContent = this.collection.getValueDescriptionFromIndex(indicatorIndexValue);
      tooltip.removeAttribute('hidden');
    },

    /**
     * Event handler executed when the user removes
     * the cursor from the slider
     * @param {Event} e Event
     */
    onMouseoutIndicatorSlider: function(e) {
      /** @type {HTMLElement} input */
      var input = e.target;
      var tooltip = input.parentElement.querySelector('.tooltip');

      tooltip.setAttribute('hidden', 'true');
    },

    /**
     * Event handler executed when the user toggles an
     * indicator
     * @param {Event} e Event
     */
    onChangeIndicatorToggle: function (e) {
      /** @type {HTMLElement} input */
      var input = e.target;
      var indicatorName = input.getAttribute('data-indicator');
      var indicatorChecked = input.checked;
      var indicatorIndexValue = indicatorChecked
        ? Math.floor((this.collection.getIndexableIndicatorValueRange()[1] - this.collection.getIndexableIndicatorValueRange()[0]) / 2)
        : null;
      var indicatorRealValue = this.collection.getRealIndicatorValueFromIndex(indicatorIndexValue);
      var indicatorHumanReadableValue = this.collection.getHumanReadableIndicatorValueFromIndex(indicatorIndexValue);

      // We update the human readable value next to the slider
      var textInput = input.closest('li').querySelector('.opacity-teller');
      textInput.value = indicatorHumanReadableValue;

      // We update the position of the slider's "runnable" track
      var runnableTrack = input.closest('li').querySelector('.opacity');
      runnableTrack.style.width = ((indicatorIndexValue / this.collection.getIndexableIndicatorValueRange()[1]) * 100) + '%';

      // We update the value of the slider
      if (indicatorIndexValue !== null) {
        var slider = input.closest('li').querySelector('.js-indicator-slider');
        slider.value = indicatorIndexValue;
      }

      // We toggle the visibility of the slider
      var sliderContainer = input.closest('li').querySelector('.m-form-input--slider');
      if (indicatorChecked) {
        sliderContainer.removeAttribute('hidden');
      } else {
        sliderContainer.setAttribute('hidden', true);
      }

      // We update the state of the model
      this.updateModel(indicatorName, {
        value: indicatorRealValue,
        indexableValue: indicatorIndexValue,
        humanReadableValue: indicatorHumanReadableValue
      });
    },

    /**
     * Event handler executed when the user clicks
     * the Apply button
     */
    onClickApply: function() {
      Backbone.Events.trigger('map:show:model');
    },

    /**
     * Event handler executed when the user clicks
     * the Reset button
     */
    onClickReset: function() {
      var modelName = this.model.attributes.name;
      var model = this.collection.findWhere({ name: modelName }).toJSON();
      this.model.set(model);
      this.render();
      Backbone.Events.trigger('map:show:model');
    },

    /**
     * Silently update the model object stored in the state
     * @param {string} indicatorName Name of the indicator
     * @param {object} indicatorAttributes Attributes to assign to the indicator
     */
    updateModel: function(indicatorName, indicatorAttributes) {
      var model = _.extend({}, this.model.attributes, {
        indicators: this.model.attributes.indicators.map(function (indicator) {
          if (indicator.name !== indicatorName) {
            return indicator;
          }

          return _.extend({}, indicator, indicatorAttributes);
        })
      });

      this.model.set(model, { silent: true });
      this.updateURL();
    },

    /**
     * Update the URL according to the state of the component
     */
    updateURL: function() {
      this.router.setParams('model', {
        name: this.model.get('name'),
        values: this.model.get('indicators').map(function(indicator) {
          return indicator.indexableValue
        })
      })
    },

    render: function() {
      var categories = (!this.model || !this.model.get('indicators'))
        ? []
        : this.model.get('indicators')
          .map(function(ind) {
            return ind.category;
          })
          .filter(function(category, i, arr) {
            return arr.indexOf(category) === i;
          });

      var formattedModel = !this.model || !categories.length
        ? null
        : {
          name: this.model.get('name'),
          categories: categories.map(function(category) {
            return {
              name: category,
              indicators: _.sortBy(this.model.get('indicators')
                .filter(function(ind) {
                  return ind.category === category;
                }), 'position')
            };
          }.bind(this))
        };

      this.$el.html(this.template({
        models: this.collection.toJSON(),
        model: formattedModel,
        indicatorRange: {
          min: this.collection.getIndexableIndicatorValueRange()[0],
          max: this.collection.getIndexableIndicatorValueRange()[1]
        }
      }));
    }
  });

})(this);
