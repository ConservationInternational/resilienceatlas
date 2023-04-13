import { subdomain } from 'utilities/getSubdomain';
import api, { createApiAction } from '../../utils/api';
import { layer, source } from '../../schema';
import { toBackendLocale } from 'utilities';

// TODO: migrate
// const URL_LAYERS = `/layers?lang=${window.currentLocation || 'en'}`;
const URL_LAYERS = `/layers`;

// Action constants
export const LOAD = createApiAction('layers/LOAD');
export const TOGGLE = 'layers / TOGGLE';
export const SET_ACTIVES = 'layers / SET_ACTIVES';
export const SET_OPACITY = 'layers / SET_OPACITY';
export const SET_CHART_LIMIT = 'layers / SET_CHART_LIMIT';
export const REORDER = 'layers / REORDER';

export const load = (locale) =>
  api(
    LOAD,
    ({ get }) =>
      get(URL_LAYERS, { params: { site_scope: subdomain, locale: toBackendLocale(locale) } }),
    {
      schema: [layer],
      includedSchema: [source],
      locale,
    },
  );

export const setActives = (actives) => ({
  type: SET_ACTIVES,
  actives,
});

export const toggle = (id) => ({
  type: TOGGLE,
  id,
});

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

export const setChartLimit = (id, chartLimit) => ({
  type: SET_CHART_LIMIT,
  id,
  chartLimit,
});
