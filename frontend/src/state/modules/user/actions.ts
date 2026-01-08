import { SubmissionError } from 'redux-form';

import { AUTH_TOKEN } from 'utilities/constants';

import { PORT, get, post, patch } from '../../utils/api';
import type { ILoginForm, ISignupForm, IEditProfileForm } from './utils';
import { getUserToken } from './selectors';

const URL_LOGIN = '/users/authenticate';
const URL_SIGNUP = '/users/register';
const URL_USER_DATA = '/users/me';

// Action constants
export const LOGIN = 'user / LOGIN';
export const SIGNUP = 'user / SIGNUP';
export const LOGOUT = 'user / LOGOUT';
export const LOAD_USER = 'user / LOAD_USER';

// Action creators
export const userLoggedIn = (auth_token) => ({
  type: LOGIN,
  auth_token,
});

export const userSignedUp = (payload) => ({
  type: SIGNUP,
  payload,
});

export const userLoggedOut = () => ({
  type: LOGOUT,
});

export const userDataLoaded = (data) => ({
  type: LOAD_USER,
  data,
});

// Actions
export const signin = ({ email, password }: ILoginForm) =>
  post(URL_LOGIN, { data: { email, password }, baseURL: PORT })
    .then((response) => response.data)
    .then((data) => {
      if (data.error || !data.auth_token) {
        throw new SubmissionError({ _error: data.error });
      }

      return data.auth_token;
    });

export const signup = (values: ISignupForm) =>
  post(URL_SIGNUP, { data: { user: values }, baseURL: PORT })
    .then((response) => response.data)
    .then((data) => {
      if (data.status !== 'created') {
        throw new SubmissionError(data);
      }

      return data;
    });

export const loadUserData = () => (dispatch, getState) =>
  get(URL_USER_DATA, {
    baseURL: PORT,
    headers: {
      Authorization: `Bearer ${getUserToken(getState())}`,
    },
  })
    .then((response) => response.data)
    .then((data) => dispatch(userDataLoaded(data)));

export const editProfile = (values: IEditProfileForm, _, props) =>
  patch(URL_USER_DATA, {
    data: { user: values },
    baseURL: PORT,
    headers: {
      Authorization: `Bearer ${props.user.auth_token}`,
    },
  }).catch((response) => {
    if (response.data?.errors) {
      throw new SubmissionError(
        Object.entries(response.data?.errors as Record<string, string[]>).reduce(
          (res, tuple) => ({
            ...res,
            [tuple[0]]: tuple[1].join(', '),
          }),
          {},
        ),
      );
    } else {
      throw new SubmissionError({ _error: 'Unable to edit the profile' });
    }
  });

export const login = (auth_token) => (dispatch) => {
  localStorage.setItem(AUTH_TOKEN, auth_token);

  dispatch(userLoggedIn(auth_token));
};

export const logout = () => (dispatch) => {
  localStorage.removeItem(AUTH_TOKEN);

  dispatch(userLoggedOut());
};
