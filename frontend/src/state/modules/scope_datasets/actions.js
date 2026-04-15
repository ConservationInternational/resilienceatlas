import { subdomain } from 'utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { requestHandlers } from '../../utils/api';

const URL_SCOPE_DATASETS = '/scope-datasets';

// Deduplicate in-flight detail requests — prevents multiple identical fetches
// when the component re-renders while a request is still pending.
const pendingDetails = new Set();

export const LOAD = createApiAction('scopeDatasets/LOAD');
export const LOAD_DETAIL = createApiAction('scopeDatasets/LOAD_DETAIL');
export const SET_HIGHLIGHT = 'scopeDatasets / SET_HIGHLIGHT';
export const CLEAR_HIGHLIGHT = 'scopeDatasets / CLEAR_HIGHLIGHT';
export const SET_HIGHLIGHT_BOUNDS = 'scopeDatasets / SET_HIGHLIGHT_BOUNDS';
export const SET_ACTIVE_VARIANT = 'scopeDatasets / SET_ACTIVE_VARIANT';
export const SET_ACTIVE_DIMENSION = 'scopeDatasets / SET_ACTIVE_DIMENSION';
export const SET_SPATIAL_FILTER = 'scopeDatasets / SET_SPATIAL_FILTER';
export const CLEAR_SPATIAL_FILTER = 'scopeDatasets / CLEAR_SPATIAL_FILTER';

export const load = (siteScope) =>
  api(
    LOAD,
    ({ get }) =>
      get(URL_SCOPE_DATASETS, {
        params: { site_scope: siteScope || subdomain },
      }),
    {},
  );

export const loadDetail = (slug, siteScope) => (dispatch) => {
  // Skip if this slug already has an in-flight request
  if (pendingDetails.has(slug)) return Promise.resolve();
  pendingDetails.add(slug);

  return dispatch(
    api(
      LOAD_DETAIL,
      ({ get }) =>
        get(`${URL_SCOPE_DATASETS}/${slug}`, {
          params: { site_scope: siteScope || subdomain },
        }),
      { slug },
    ),
  ).finally(() => {
    pendingDetails.delete(slug);
  });
};

export const setHighlight = (datasetSlug, unitId) => ({
  type: SET_HIGHLIGHT,
  datasetSlug,
  unitId,
});

export const clearHighlight = () => ({
  type: CLEAR_HIGHLIGHT,
});

export const fetchGeometryBounds = (datasetSlug, unitId) => (dispatch) => {
  return requestHandlers
    .get(`${URL_SCOPE_DATASETS}/${datasetSlug}/geometry-bounds/${unitId}`, {
      params: { site_scope: subdomain },
    })
    .then(({ data }) => {
      if (data && data.bounds) {
        dispatch({ type: SET_HIGHLIGHT_BOUNDS, bounds: data.bounds });
      }
    })
    .catch(() => {
      // Bounds fetch is best-effort — don't break the app
    });
};

export const setActiveVariant = (variant) => ({
  type: SET_ACTIVE_VARIANT,
  variant,
});

export const setActiveDimension = (dimension) => ({
  type: SET_ACTIVE_DIMENSION,
  dimension,
});

export const fetchIntersectingUnits =
  ({ iso, geometry } = {}) =>
  (dispatch) => {
    const params = { site_scope: subdomain };
    if (iso) params.iso = iso;
    else if (geometry)
      params.geometry = typeof geometry === 'string' ? geometry : JSON.stringify(geometry);
    else return Promise.resolve();

    return requestHandlers
      .get(`${URL_SCOPE_DATASETS}/intersecting-units`, { params })
      .then(({ data }) => {
        dispatch({ type: SET_SPATIAL_FILTER, payload: data });
      })
      .catch(() => {
        // Spatial filter is optional — don't break the app
      });
  };

export const clearSpatialFilter = () => ({
  type: CLEAR_SPATIAL_FILTER,
});
