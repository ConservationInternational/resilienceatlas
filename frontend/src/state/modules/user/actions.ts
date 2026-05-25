import { get, post, patch } from '../../utils/api';
import type { ILoginForm, ISignupForm, IEditProfileForm } from './utils';
import { getUserToken } from './selectors';

// Custom error class for form submission errors
export class FormSubmissionError extends Error {
  errors: Record<string, string>;
  _error?: Record<string, string>;

  constructor(errors: Record<string, string>) {
    super('Form submission error');
    this.name = 'FormSubmissionError';
    this.errors = errors;
    this._error = errors;
  }
}

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
export const signin = async ({ email, password }: ILoginForm): Promise<void> => {
  const res = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new FormSubmissionError({ _error: data.error });
  }
};

export const signup = (values: ISignupForm) =>
  post(URL_SIGNUP, { data: { user: values } })
    .then((response) => response.data)
    .then((data) => {
      if (data.status !== 'created') {
        throw new FormSubmissionError(data);
      }
      return data;
    });

export const loadUserData = () => (dispatch, getState) =>
  get(URL_USER_DATA, {
    headers: {
      Authorization: `Bearer ${getUserToken(getState())}`,
    },
  })
    .then((response) => response.data)
    .then((data) => dispatch(userDataLoaded(data)));

export const editProfile = (values: IEditProfileForm, authToken: string) =>
  patch(URL_USER_DATA, {
    data: { user: values },
    headers: {
      Authorization: `Bearer ${authToken}`,
    },
  }).catch((response) => {
    if (response.data?.errors) {
      throw new FormSubmissionError(
        Object.entries(response.data?.errors as Record<string, string[]>).reduce(
          (res, tuple) => ({
            ...res,
            [tuple[0]]: tuple[1].join(', '),
          }),
          {},
        ),
      );
    } else {
      throw new FormSubmissionError({ _error: 'Unable to edit the profile' });
    }
  });

export const login = (auth_token: string) => (dispatch) => {
  // Token is held in Redux memory only — never written to localStorage.
  dispatch(userLoggedIn(auth_token));
};

export const logout = () => async (dispatch) => {
  await fetch('/api/auth/logout', { method: 'POST' });
  dispatch(userLoggedOut());
};
