import { createReducer } from '../../utils';
import { LOAD_ONE as LOAD_JOURNEY } from '../journeys/actions';

const initialState = {
  data: {},
  current: null, // journeyID
  loading: false,
  loaded: null, // journeyID
  error: null,
};

export default createReducer(initialState)({
  [LOAD_JOURNEY.REQUEST]: (state, { meta: { id } }) => ({
    ...state,
    current: id,
    loading: true,
    error: null,
  }),

  [LOAD_JOURNEY.SUCCESS]: (state, { payload, meta: { id } }) => ({
    ...state,
    data: { ...payload.data, steps: payload.included },
    loading: false,
    loaded: id,
  }),

  [LOAD_JOURNEY.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    error,
  }),
});
