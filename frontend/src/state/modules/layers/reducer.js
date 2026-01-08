import { createReducer } from '../../utils';
import {
  LOAD,
  SET_ACTIVES,
  TOGGLE,
  SET_OPACITY,
  REORDER,
  SET_CHART_LIMIT,
  SET_DATE,
} from './actions';
import { getPersistedLayers, URL_PERSISTED_KEYS } from './utils';

const persistedLayers = getPersistedLayers();

const initialState = {
  byId: {
    /* [layerId]: { layer } */
    ...persistedLayers.entities.persisted_layers,
  },
  all: [
    /* layerId */
  ],
  actives: [...persistedLayers.result],
  loading: false,
  loaded: false,
  loadedLocale: null,
  loadedSubdomain: null,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),

  [LOAD.SUCCESS]: (state, { payload, meta: { locale, subdomain } }) => {
    const {
      entities: { layers },
      result,
    } = payload;
    const { byId: persistedById } = state;

    // Clear up active layers in case of changing subdomain
    // we receiving different sets of layers
    // TBD: maybe clear in URL as well

    const actives = new Set(state.actives.filter((id) => layers[id]));

    // Toggling default active layers, received from backend
    result.forEach((id) => {
      if (layers[id].active) actives.add(+id);
    });

    // Update fetched layers with persisted data
    const persistedValues = (id) =>
      URL_PERSISTED_KEYS.reduce((acc, key) => {
        if (persistedById[id] && persistedById[id][key]) {
          acc[key] = persistedById[id][key];
        }
        return acc;
      }, {});

    const updatedLayers = Object.keys(state.byId).reduce(
      (acc, id) => {
        if (layers[id]) {
          acc[id] = { ...layers[id], ...persistedValues(id) };
        }
        return acc;
      },
      { ...layers },
    );

    return {
      ...state,
      byId: updatedLayers,
      all: payload.result,
      actives: [...actives],
      loading: false,
      loaded: true,
      loadedLocale: locale,
      loadedSubdomain: subdomain,
    };
  },

  [LOAD.FAIL]: (state) => ({
    ...state,
    loading: false,
    error: true,
  }),

  [SET_ACTIVES]: (state, { actives }) => ({
    ...state,
    actives,
  }),

  [TOGGLE]: (state, { id }) => {
    const actives = new Set(state.actives);
    let sorted_actives = new Set(); // sort by latest active layer on top

    if (actives.has(id)) {
      actives.delete(id);
      sorted_actives = new Set([...actives]);
    } else {
      const actives_list = [...actives];
      actives_list.unshift(id);
      sorted_actives = new Set(actives_list);
    }

    return {
      ...state,
      actives: [...sorted_actives],
    };
  },

  [REORDER]: (state, { startIndex, endIndex }) => {
    const actives = [...state.actives];
    const [removed] = actives.splice(startIndex, 1);
    actives.splice(endIndex, 0, removed);

    return {
      ...state,
      actives,
    };
  },

  [SET_OPACITY]: (state, { id, opacity }) => ({
    ...state,
    byId: {
      ...state.byId,
      [id]: {
        ...state.byId[id],
        opacity,
      },
    },
  }),
  [SET_DATE]: (state, { id, date }) => ({
    ...state,
    byId: {
      ...state.byId,
      [id]: {
        ...state.byId[id],
        date,
      },
    },
  }),

  [SET_CHART_LIMIT]: (state, { id, chartLimit }) => ({
    ...state,
    byId: {
      ...state.byId,
      [id]: {
        ...state.byId[id],
        chartLimit,
      },
    },
  }),
});
