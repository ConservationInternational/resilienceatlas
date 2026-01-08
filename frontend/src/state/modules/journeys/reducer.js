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
  loadedLocale: null,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),

  [LOAD.SUCCESS]: (state, { payload, meta: { locale } }) => ({
    ...state,
    byId: payload.entities.journeys,
    all: payload.result,
    loading: false,
    loaded: true,
    loadedLocale: locale,
  }),

  [LOAD.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    error,
  }),
});
