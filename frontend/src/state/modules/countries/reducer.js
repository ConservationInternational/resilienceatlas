import { createReducer } from '../../utils';
import { LOAD } from './actions';

const initialState = {
  byISO: {
    /* [ISO]: { name, iso, bbox } */
  },
  all: [
    /* ISO */
  ],
  loading: false,
  loaded: false,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: state => ({
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
});
