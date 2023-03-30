import { SubmissionError } from 'redux-form';

import { AUTH_TOKEN } from 'utilities/constants';

import { PORT, post } from '../../utils/api';
import type { ILoginForm, ISignupForm, IEditProfileForm } from './utils';

const URL_LOGIN = '/users/authenticate';
const URL_SIGNUP = '/users/register';

// Action constants
export const LOGIN = 'user / LOGIN';
export const SIGNUP = 'user / SIGNUP';
export const EDIT_PROFILE = 'user / EDIT_PROFILE';
export const LOGOUT = 'user / LOGOUT';

// Action creators
export const userLoggedIn = (auth_token) => ({
  type: LOGIN,
  auth_token,
});

export const userSignedUp = (payload) => ({
  type: SIGNUP,
  payload,
});

export const userProfileEdited = (payload) => ({
  type: EDIT_PROFILE,
  payload,
});

export const userLoggedOut = () => ({
  type: LOGOUT,
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

export const editProfile = (values: IEditProfileForm) =>
  // MOCK
  new Promise((resolve) => {
    setTimeout(
      () =>
        resolve({
          ...values,
        }),
      Math.random() * 2000,
    );
  });

export const login = (auth_token) => (dispatch) => {
  localStorage.setItem(AUTH_TOKEN, auth_token);

  dispatch(userLoggedIn(auth_token));
};

export const logout = () => (dispatch) => {
  localStorage.removeItem(AUTH_TOKEN);

  dispatch(userLoggedOut());
};
