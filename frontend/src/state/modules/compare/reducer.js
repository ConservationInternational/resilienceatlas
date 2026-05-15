import { createReducer } from '../../utils';
import { getCompareStateFromURL } from './utils';
import {
  ENABLE_COMPARE,
  DISABLE_COMPARE,
  SET_LEFT_LAYER,
  SET_RIGHT_LAYER,
  SET_SLIDER_POSITION,
  CLEAR_LAYER,
} from './actions';

// Initialize from URL if available
const urlState = getCompareStateFromURL();

const initialState = {
  enabled: urlState.enabled || false,
  leftLayerId: urlState.leftLayerId || null,
  rightLayerId: urlState.rightLayerId || null,
  sliderPosition: urlState.sliderPosition || 50,
};

export default createReducer(initialState)({
  [ENABLE_COMPARE]: (state) => ({
    ...state,
    enabled: true,
  }),

  [DISABLE_COMPARE]: () => ({
    enabled: false,
    leftLayerId: null,
    rightLayerId: null,
    sliderPosition: 50,
  }),

  [SET_LEFT_LAYER]: (state, { layerId }) => ({
    ...state,
    leftLayerId: layerId,
  }),

  [SET_RIGHT_LAYER]: (state, { layerId }) => ({
    ...state,
    rightLayerId: layerId,
  }),

  [SET_SLIDER_POSITION]: (state, { position }) => ({
    ...state,
    sliderPosition: Math.min(100, Math.max(0, position)),
  }),

  [CLEAR_LAYER]: (state, { side }) => ({
    ...state,
    [side === 'left' ? 'leftLayerId' : 'rightLayerId']: null,
  }),
});
