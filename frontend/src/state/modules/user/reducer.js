import { createReducer } from '../../utils';
import { LOGIN, LOGOUT, LOAD_USER } from './actions';

const initialState = {
  auth_token: null,
  data: null,
};

export default createReducer(initialState)({
  [LOGIN]: (state, { auth_token }) => ({
    ...state,
    auth_token,
  }),

  [LOGOUT]: () => ({
    auth_token: null,
  }),

  [LOAD_USER]: (state, { data }) => ({
    ...state,
    data,
  }),
});
