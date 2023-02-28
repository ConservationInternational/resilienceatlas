import { createReducer } from '../../utils';
import { LOGIN, EDIT_PROFILE, LOGOUT } from './actions';

const initialState = {
  auth_token: null,
};

export default createReducer(initialState)({
  [LOGIN]: (state, { auth_token }) => ({
    ...state,
    auth_token,
  }),

  [EDIT_PROFILE]: (state, { payload }) => ({
    ...state,
    ...payload,
  }),

  [LOGOUT]: () => ({
    auth_token: null,
  }),
});
