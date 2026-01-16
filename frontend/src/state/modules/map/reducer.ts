import { subdomain } from 'utilities/getSubdomain';
import { getRouterParam } from 'utilities';
import { createReducer } from '../../utils';
import * as t from './actions';
import type { MAP_LABELS } from 'views/components/LayersList/Basemaps/constants';

interface Bounds {
  _northEast: { lat: number; lng: number };
  _southWest: { lat: number; lng: number };
}

interface LayerInteraction {
  id: string;
  [key: string]: unknown;
}

interface LatLng {
  lat: number;
  lng: number;
}

interface GeoJSONFeature {
  type: string;
  geometry: unknown;
  properties?: Record<string, unknown>;
}

export interface MapState {
  labels: (typeof MAP_LABELS)[number];
  drawing: boolean;
  bounds: Bounds | null;
  iso: string | null;
  basemap: string;
  layerGroupsInteraction: Record<string, LayerInteraction>;
  layerGroupsInteractionSelected: LayerInteraction | null;
  layerGroupsInteractionLatLng: LatLng | null;
  geojson?: GeoJSONFeature | null;
}

// Use consistent defaults for initial state to prevent hydration mismatch.
// The actual URL params and subdomain-based values are synced after hydration
// via the useRouterValue hooks in the Basemaps component.
const initialState: MapState = {
  drawing: false,
  // geojson: getRouterParam('geojson', JSON.parse),
  bounds: null,
  iso: null,
  basemap: 'defaultmap',
  labels: 'none',
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
