import { subdomain } from 'utilities/getSubdomain';
import { post, get } from '../../utils/api';

const URL_SITE_SCOPE_AUTH = '/site-scope/authenticate';
const URL_SITE_SCOPE_CHECK = '/site-scope/check-access';

// Action constants
export const SITE_SCOPE_AUTH_REQUEST = 'site_scope_auth/AUTH_REQUEST';
export const SITE_SCOPE_AUTH_SUCCESS = 'site_scope_auth/AUTH_SUCCESS';
export const SITE_SCOPE_AUTH_FAIL = 'site_scope_auth/AUTH_FAIL';
export const SITE_SCOPE_CHECK_REQUEST = 'site_scope_auth/CHECK_REQUEST';
export const SITE_SCOPE_CHECK_SUCCESS = 'site_scope_auth/CHECK_SUCCESS';
export const SITE_SCOPE_CHECK_FAIL = 'site_scope_auth/CHECK_FAIL';
export const SITE_SCOPE_AUTH_CLEAR = 'site_scope_auth/AUTH_CLEAR';
export const SITE_SCOPE_AUTH_SHOW_MODAL = 'site_scope_auth/SHOW_MODAL';
export const SITE_SCOPE_AUTH_HIDE_MODAL = 'site_scope_auth/HIDE_MODAL';

// Action creators
export const showAuthModal = (siteScope = subdomain) => ({
  type: SITE_SCOPE_AUTH_SHOW_MODAL,
  payload: { siteScope },
});

export const hideAuthModal = () => ({
  type: SITE_SCOPE_AUTH_HIDE_MODAL,
});

export const clearAuthError = () => ({
  type: SITE_SCOPE_AUTH_CLEAR,
});

// Thunk actions
export const checkSiteScopeAccess =
  (siteScope = subdomain) =>
  (dispatch) => {
    dispatch({ type: SITE_SCOPE_CHECK_REQUEST });

    return get(URL_SITE_SCOPE_CHECK, {
      params: { site_scope: siteScope },
    })
      .then(({ data }) => {
        dispatch({
          type: SITE_SCOPE_CHECK_SUCCESS,
          payload: {
            siteScope,
            requiresAuthentication: data.requires_authentication,
            authenticated: data.authenticated,
          },
        });

        // If authentication is required but not authenticated, show modal
        if (data.requires_authentication && !data.authenticated) {
          dispatch(showAuthModal(siteScope));
        }

        return data;
      })
      .catch((error) => {
        dispatch({
          type: SITE_SCOPE_CHECK_FAIL,
          payload: { error: error.message },
        });
        throw error;
      });
  };

export const authenticateWithSiteScope = (siteScope, username, password) => (dispatch) => {
  dispatch({ type: SITE_SCOPE_AUTH_REQUEST });

  return post(URL_SITE_SCOPE_AUTH, {
    data: {
      site_scope: siteScope,
      username,
      password,
    },
  })
    .then(({ data }) => {
      if (data.authenticated && data.token) {
        // Store the token in localStorage
        localStorage.setItem(`site_scope_token_${siteScope}`, data.token);

        dispatch({
          type: SITE_SCOPE_AUTH_SUCCESS,
          payload: {
            siteScope,
            token: data.token,
            authenticated: true,
          },
        });

        dispatch(hideAuthModal());
        return data;
      } else {
        throw new Error('Authentication failed');
      }
    })
    .catch((error) => {
      const errorMessage =
        error.response?.data?.errors?.[0]?.title || error.message || 'Authentication failed';

      dispatch({
        type: SITE_SCOPE_AUTH_FAIL,
        payload: { error: errorMessage },
      });

      throw new Error(errorMessage);
    });
};

// Get stored token for site scope
export const getSiteScopeToken = (siteScope = subdomain) => {
  if (typeof window !== 'undefined') {
    return localStorage.getItem(`site_scope_token_${siteScope}`);
  }
  return null;
};

// Clear stored token for site scope
export const clearSiteScopeToken = (siteScope = subdomain) => {
  if (typeof window !== 'undefined') {
    localStorage.removeItem(`site_scope_token_${siteScope}`);
  }
};

// Check if we have a valid token stored
export const initializeSiteScopeAuth =
  (siteScope = subdomain) =>
  (dispatch) => {
    const token = getSiteScopeToken(siteScope);

    if (token) {
      // We have a token, assume authenticated for now
      // The token validity will be checked on API calls
      dispatch({
        type: SITE_SCOPE_AUTH_SUCCESS,
        payload: {
          siteScope,
          token,
          authenticated: true,
        },
      });
    }

    // Always check current access status
    return dispatch(checkSiteScopeAccess(siteScope));
  };
