import { createReducer } from '../../utils';
import { LOAD, OPEN_BATCH, TOGGLE } from './actions';

const initialState = {
  byId: {
    /* [layerId]: { layer } */
  },
  all: [
    /* layerId */
  ],
  loading: false,
  loaded: false,
  loadedLocale: null,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),
  [LOAD.SUCCESS]: (state, { payload, meta: { locale } }) => {
    return {
      ...state,
      byId: payload.entities.layer_groups,
      all: payload.result,
      loaded: true,
      loadedLocale: locale,
      loading: false,
    };
  },
  [LOAD.FAIL]: (state) => ({
    ...state,
    loading: false,
    error: true,
  }),

  [TOGGLE]: (state, { id }) => {
    const group = state.byId[id];

    return {
      ...state,
      byId: {
        ...state.byId,
        [id]: {
          ...group,
          active: !group.active,
        },
      },
    };
  },

  [OPEN_BATCH]: (state, { ids }) => ({
    ...state,
    byId: {
      ...state.byId,
      ...ids.reduce(
        (acc, id) => ({
          ...acc,
          [id]: {
            ...state.byId[id],
            active: true,
          },
        }),
        {},
      ),
    },
  }),
});
