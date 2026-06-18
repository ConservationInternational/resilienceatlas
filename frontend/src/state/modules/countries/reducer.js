import { createReducer } from '../../utils';
import { LOAD, LOAD_GEOMETRY } from './actions';

const initialState = {
  byISO: {
    /* [ISO]: { name, iso, geometry? } */
  },
  all: [
    /* ISO */
  ],
  loading: false,
  loaded: false,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),

  [LOAD.SUCCESS]: (state, { payload }) => ({
    ...state,
    loading: false,
    loaded: true,
    byISO: payload.entities.countries,
    all: payload.result.rows,
  }),

  [LOAD.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    error,
  }),

  // Merge geometry into the existing entry for this ISO code.
  [LOAD_GEOMETRY.SUCCESS]: (state, { payload }) => {
    const { iso, geometry } = payload;
    if (!iso) return state;
    return {
      ...state,
      byISO: {
        ...state.byISO,
        [iso]: {
          ...state.byISO[iso],
          geometry,
          geometryLoaded: true,
        },
      },
    };
  },

});
