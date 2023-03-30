import { createReducer } from '../../utils';
import { LOAD } from './actions';

const initialState = {
  byId: {
    /* [journeyId]: { journey } */
  },
  all: [
    /* journeyId */
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
    byId: payload.entities.journeys,
    all: payload.result,
    loding: false,
    loaded: true,
  }),

  [LOAD.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    error,
  }),
});
