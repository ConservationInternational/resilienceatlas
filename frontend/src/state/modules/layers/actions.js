import { subdomain } from 'utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { layer, source } from '../../schema';
import { toBackendLocale } from 'utilities/helpers';
import { handleLayerRemoval } from '../compare/actions';

// TODO: migrate
// const URL_LAYERS = `/layers?lang=${window.currentLocation || 'en'}`;
const URL_LAYERS = `/layers`;

// Action constants
export const LOAD = createApiAction('layers/LOAD');
export const TOGGLE = 'layers / TOGGLE';
export const SET_ACTIVES = 'layers / SET_ACTIVES';
export const SET_OPACITY = 'layers / SET_OPACITY';
export const SET_DATE = 'layers / SET_DATE';
export const SET_CHART_LIMIT = 'layers / SET_CHART_LIMIT';
export const REORDER = 'layers / REORDER';
export const ADD_LAYER_AFTER_COMPARE = 'layers / ADD_LAYER_AFTER_COMPARE';

export const load = (locale, siteScope) =>
  api(
    LOAD,
    ({ get }) =>
      get(URL_LAYERS, {
        params: { site_scope: siteScope || subdomain, locale: toBackendLocale(locale) },
      }),
    {
      schema: [layer],
      includedSchema: [source],
      locale,
      subdomain: siteScope || subdomain,
    },
  );

export const setActives = (actives) => ({
  type: SET_ACTIVES,
  actives,
});

// Basic toggle action (used internally by the thunk)
const toggleAction = (id) => ({
  type: TOGGLE,
  id,
});

/**
 * Toggle a layer on/off with compare mode awareness.
 * - When removing a layer that's in comparison, exits compare mode
 * - When adding a layer during compare mode, inserts it after comparison layers
 * @param {number|string} id - The layer ID to toggle
 */
export const toggle = (id) => (dispatch, getState) => {
  const state = getState();
  const { layers, compare } = state;
  const isActive = layers.actives.includes(id);

  if (isActive) {
    // Layer is being removed - check if it's in compare mode
    dispatch(handleLayerRemoval(id));
    dispatch(toggleAction(id));
  } else {
    // Layer is being added - check if compare mode is active with both layers
    const { enabled, leftLayerId, rightLayerId } = compare;
    if (enabled && leftLayerId && rightLayerId) {
      // Insert after comparison layers (at index 2)
      dispatch({
        type: ADD_LAYER_AFTER_COMPARE,
        id,
      });
    } else {
      // Normal toggle - add to top
      dispatch(toggleAction(id));
    }
  }
};

export const reorder = (startIndex, endIndex) => ({
  type: REORDER,
  startIndex,
  endIndex,
});

export const setOpacity = (id, opacity) => ({
  type: SET_OPACITY,
  id,
  opacity,
});

export const setDate = (id, date) => ({
  type: SET_DATE,
  id,
  date,
});

export const setChartLimit = (id, chartLimit) => ({
  type: SET_CHART_LIMIT,
  id,
  chartLimit,
});
