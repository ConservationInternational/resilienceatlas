import { subdomain } from '@utilities/getSubdomain';
import { getRouterParam } from '@utilities';
import { createReducer } from '../../utils';
import * as t from './actions';

const initialState = {
  drawing: false,
  // geojson: getRouterParam('geojson', JSON.parse),
  bounds: null,
  iso: getRouterParam('iso'),
  basemap:
    getRouterParam('basemap') ||
    (subdomain === 'atlas' ? 'satellite' : 'defaultmap'),
  layerGroupsInteraction: {},
  layerGroupsInteractionSelected: null,
  layerGroupsInteractionLatLng: null,
};

export default createReducer(initialState)({
  [t.SET_DRAWING]: (state, { payload }) => ({
    ...state,
    drawing: payload,
  }),

  [t.SET_GEOJSON]: (state, { payload }) => ({
    ...state,
    geojson: payload,
  }),

  [t.SET_BASEMAP]: (state, { payload }) => ({
    ...state,
    basemap: payload,
  }),

  [t.SET_BOUNDS]: (state, { payload }) => ({
    ...state,
    bounds: payload,
  }),

  [t.SET_ISO]: (state, { payload }) => ({
    ...state,
    iso: payload,
  }),

  [t.SET_MAP_LAYER_GROUPS_INTERACTION]: (state, { layer }) => ({
    ...state,
    layerGroupsInteraction: {
      ...state.layerGroupsInteraction,
      [layer.id]: layer,
    },
  }),

  [t.SET_MAP_LAYER_GROUPS_INTERACTION_LATLNG]: (
    state,
    { layerGroupsInteractionLatLng },
  ) => ({
    ...state,
    layerGroupsInteractionLatLng,
  }),

  [t.SET_MAP_LAYER_GROUPS_INTERACTION_SELECTED]: (
    state,
    { layerGroupsInteractionSelected },
  ) => ({
    ...state,
    layerGroupsInteractionSelected,
  }),
});
