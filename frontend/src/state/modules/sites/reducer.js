import { createReducer } from '../../utils';
import { LOAD } from './actions';

const initialState = {
  byId: {
    /* [siteId]: { site } */
  },
  all: [
    /* siteId */
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
    byId: payload.entities.site_scopes,
    all: payload.result,
    loaded: true,
    loading: false,
  }),

  [LOAD.FAIL]: (state, { error }) => ({
    ...initialState,
    error,
  }),
});
