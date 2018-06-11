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
    collection: new root.app.Collection.Models(),

    initialize: function(settings) {
      var opts = settings && settings.options ? settings.options : {};
      this.options = _.extend({}, this.defaults, opts);

      this.state = new Backbone.Model({
        model: null
      });

      this.setListeners();

      this.collection.fetch()
        .done(function() {
          this.render();
        }.bind(this));
    },

    /**
     * Set the listeners that aren't attached
     * to a DOM node
     */
    setListeners: function() {
      this.listenTo(this.state, 'change:model', this.render.bind(this));
    },

    /**
     * Event handler executed when the user changes the
     * value of the model selector
     * @param {Event} e Event
     */
    onChangeModelSelector: function(e) {
      var modelName = e.target.selectedOptions[0].value;
      var model = this.collection.findWhere({ name: modelName }).toJSON();
      this.state.set({ model: model });
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
      runnableTrack.style.width = (indicatorIndexValue / this.collection.getIndexableIndicatorValueRange()[1]) + '%';

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
      // TODO: implement what happens when the user
      // applies the model
    },

    /**
     * Event handler executed when the user clicks
     * the Reset button
     */
    onClickReset: function() {
      var modelName = this.state.get('model').name;
      var model = this.collection.findWhere({ name: modelName }).toJSON();
      this.state.set({ model: model });
      this.render();
    },

    /**
     * Silently update the model object stored in the state
     * @param {string} indicatorName Name of the indicator
     * @param {object} indicatorAttributes Attributes to assign to the indicator
     */
    updateModel(indicatorName, indicatorAttributes) {
      var model = _.extend({}, this.state.get('model'), {
        indicators: this.state.get('model').indicators.map(function (indicator) {
          if (indicator.name !== indicatorName) {
            return indicator;
          }

          return _.extend({}, indicator, indicatorAttributes);
        })
      });

      this.state.set({ model: model }, { silent: true });
    },

    render: function() {
      this.$el.html(this.template({
        models: this.collection.toJSON(),
        model: this.state.get('model'),
        indicatorRange: {
          min: this.collection.getIndexableIndicatorValueRange()[0],
          max: this.collection.getIndexableIndicatorValueRange()[1]
        }
      }));
    }
  });

})(this);
