import { createReducer } from '../../utils';
import {
  LOAD,
  LOAD_DETAIL,
  SET_HIGHLIGHT,
  CLEAR_HIGHLIGHT,
  SET_HIGHLIGHT_BOUNDS,
  SET_HIGHLIGHT_GEOMETRY,
  SET_ACTIVE_VARIANT,
  SET_ACTIVE_DIMENSION,
  SET_SPATIAL_FILTER,
  CLEAR_SPATIAL_FILTER,
} from './actions';

// Convert snake_case string to camelCase
const toCamel = (s) => s.replace(/_([a-z])/g, (_, c) => c.toUpperCase());

// Recursively convert object keys from snake_case to camelCase
const camelizeKeys = (obj) => {
  if (Array.isArray(obj)) return obj.map(camelizeKeys);
  if (obj !== null && typeof obj === 'object') {
    return Object.fromEntries(Object.entries(obj).map(([k, v]) => [toCamel(k), camelizeKeys(v)]));
  }
  return obj;
};

// Flatten a JSONAPI resource {id, type, attributes: {...}} into {id, ...attributes}
// Also camelize keys in chart_config and schema_config (but not data rows)
const flattenResource = (resource) => {
  if (resource && resource.attributes) {
    const attrs = { ...resource.attributes };
    if (attrs.chart_config) attrs.chart_config = camelizeKeys(attrs.chart_config);
    if (attrs.schema_config) attrs.schema_config = camelizeKeys(attrs.schema_config);
    if (attrs.dimension_config) attrs.dimension_config = camelizeKeys(attrs.dimension_config);
    return { id: resource.id, ...attrs };
  }
  return resource;
};

const initialState = {
  datasets: [],
  bySlug: {},
  loading: false,
  loaded: false,
  error: null,
  highlight: null,
  highlightBounds: null,
  highlightGeometry: null,
  detailLoading: {},
  activeVariant: null,
  activeDimension: null,
  spatialFilter: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),
  [LOAD.SUCCESS]: (state, { payload }) => {
    const rawList = payload.data || [];
    const datasets = Array.isArray(rawList) ? rawList.map(flattenResource) : [];
    const bySlug = {};
    datasets.forEach((d) => {
      if (d.slug) {
        bySlug[d.slug] = { ...d, detailLoaded: false };
      }
    });
    return {
      ...state,
      loading: false,
      loaded: true,
      datasets,
      bySlug,
    };
  },
  [LOAD.FAIL]: (state) => ({
    ...state,
    loading: false,
    error: true,
  }),

  [LOAD_DETAIL.REQUEST]: (state, { meta }) => ({
    ...state,
    detailLoading: { ...state.detailLoading, [meta?.slug]: true },
  }),
  [LOAD_DETAIL.SUCCESS]: (state, { payload, meta }) => {
    const dataset = flattenResource(payload.data);
    const slug = meta?.slug || dataset?.slug;
    return {
      ...state,
      detailLoading: { ...state.detailLoading, [slug]: false },
      bySlug: {
        ...state.bySlug,
        [slug]: { ...dataset, detailLoaded: true },
      },
    };
  },
  [LOAD_DETAIL.FAIL]: (state, { meta }) => ({
    ...state,
    detailLoading: { ...state.detailLoading, [meta?.slug]: false },
  }),

  [SET_HIGHLIGHT]: (state, { datasetSlug, unitId }) => {
    // Toggle: if clicking the same row, clear the highlight
    if (
      state.highlight &&
      state.highlight.datasetSlug === datasetSlug &&
      state.highlight.unitId === unitId
    ) {
      return {
        ...state,
        highlight: null,
        highlightBounds: null,
        highlightGeometry: null,
      };
    }
    return {
      ...state,
      highlight: { datasetSlug, unitId },
      highlightBounds: null,
      highlightGeometry: null,
    };
  },
  [CLEAR_HIGHLIGHT]: (state) => ({
    ...state,
    highlight: null,
    highlightBounds: null,
    highlightGeometry: null,
  }),

  [SET_HIGHLIGHT_BOUNDS]: (state, { bounds }) => ({
    ...state,
    highlightBounds: bounds,
  }),

  [SET_HIGHLIGHT_GEOMETRY]: (state, { geometry }) => ({
    ...state,
    highlightGeometry: geometry,
  }),

  [SET_ACTIVE_VARIANT]: (state, { variant }) => ({
    ...state,
    activeVariant: variant,
  }),
  [SET_ACTIVE_DIMENSION]: (state, { dimension }) => ({
    ...state,
    activeDimension: dimension,
  }),

  [SET_SPATIAL_FILTER]: (state, { payload }) => ({
    ...state,
    spatialFilter: payload,
  }),
  [CLEAR_SPATIAL_FILTER]: (state) => ({
    ...state,
    spatialFilter: null,
  }),
});
