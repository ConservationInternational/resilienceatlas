import { subdomain } from 'utilities/getSubdomain';
import { getRouterParam } from 'utilities';
import { createReducer } from '../../utils';
import * as t from './actions';
import type { MAP_LABELS } from 'views/components/LayersList/Basemaps/constants';

export interface MapState {
  labels: (typeof MAP_LABELS)[number];
  drawing: boolean;
  bounds: any;
  iso: string | null;
  basemap: string;
  layerGroupsInteraction: Record<string, any>;
  layerGroupsInteractionSelected: any;
  layerGroupsInteractionLatLng: any;
  geojson?: any;
}

const initialState: MapState = {
  drawing: false,
  // geojson: getRouterParam('geojson', JSON.parse),
  bounds: null,
  iso: getRouterParam('iso'),
  basemap: getRouterParam('basemap') || (subdomain === 'atlas' ? 'satellite' : 'defaultmap'),
  labels: (getRouterParam('labels') as (typeof MAP_LABELS)[number]) || 'none',
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
  [t.SET_LABELS]: (state, { payload }) => ({
    ...state,
    labels: payload,
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

  [t.SET_MAP_LAYER_GROUPS_INTERACTION_LATLNG]: (state, { layerGroupsInteractionLatLng }) => ({
    ...state,
    layerGroupsInteractionLatLng,
  }),

  [t.SET_MAP_LAYER_GROUPS_INTERACTION_SELECTED]: (state, { layerGroupsInteractionSelected }) => ({
    ...state,
    layerGroupsInteractionSelected,
  }),
});
