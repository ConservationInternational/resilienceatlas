import qs from 'qs';
import { Array } from 'core-js';
import { getRouterParam } from '@utilities';
import { createReducer } from '../../utils';
import {
  LOAD,
  SELECT,
  TOGGLE_INDICATOR,
  UDPATE_INDICATOR,
  APPLY_INDICATORS,
  RESET_INDICATORS,
} from './actions';
import {
  getIndexableIndicatorValueRange,
  buildIndicatorsFromState,
} from './utils';

const {
  name: persistedModel = null,
  values: persistedIndicators = [],
} = getRouterParam('model', val =>
  qs.parse(val, { parseArrays: true, comma: true }),
);

const initialState = {
  byId: {
    /* [modelId]: { model } */
  },
  all: [
    /* modelId */
  ],
  selected: persistedModel,
  indicators: {
    /* [indicatorId]: { indicator } */
  },
  indicators_state: persistedIndicators.map(Number),
  categories: {
    /* [categoryId]: { category } */
  },
  loading: false,
  loaded: false,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: state => ({
    ...state,
    loading: true,
    error: null,
  }),

  [LOAD.SUCCESS]: (state, { payload, included }) => {
    const { models = {} } = payload.entities;
    const { categories, indicators } = included.entities;
    const newState = {
      ...state,
      byId: models,
      all: payload.result,
      categories,
      indicators,
      loading: false,
      loaded: true,
    };

    const newIndicators = buildIndicatorsFromState(newState);

    return {
      ...newState,
      indicators: {
        ...indicators,
        ...newIndicators,
      },
    };
  },

  [LOAD.FAIL]: (state, { error }) => ({
    ...initialState,
    loading: false,
    error,
  }),

  [SELECT]: (state, { id }) => {
    const model = state.byId[id];

    return {
      ...state,
      selected: id,
      indicators_state: model.indicators.map(
        ind => state.indicators[ind].indexableValue,
      ),
    };
  },

  [TOGGLE_INDICATOR]: (state, { index }) => {
    const [min, max] = getIndexableIndicatorValueRange();
    const newIndicatorsState = [...state.indicators_state];
    const indicatorValue = newIndicatorsState[index];
    const indexableValue = indicatorValue ? null : (max - min) / 2;
    newIndicatorsState.splice(index, 1, indexableValue);

    return {
      ...state,
      indicators_state: newIndicatorsState,
    };
  },

  [UDPATE_INDICATOR]: (state, { index, indexableValue }) => {
    const newIndicatorsState = [...state.indicators_state];

    newIndicatorsState.splice(index, 1, indexableValue);

    return {
      ...state,
      indicators_state: newIndicatorsState,
    };
  },

  [APPLY_INDICATORS]: state => {
    const newIndicators = buildIndicatorsFromState(state);

    return {
      ...state,
      indicators: {
        ...state.indicators,
        ...newIndicators,
      },
    };
  },

  [RESET_INDICATORS]: state => {
    const newIndicatorsState = Array.from(state.indicators_state).fill(4);
    const newIndicators = buildIndicatorsFromState(state, newIndicatorsState);

    return {
      ...state,
      indicators: {
        ...state.indicators,
        ...newIndicators,
      },
      indicators_state: newIndicatorsState,
    };
  },
});
