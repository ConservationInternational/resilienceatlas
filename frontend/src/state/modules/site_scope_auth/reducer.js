import {
  SITE_SCOPE_AUTH_REQUEST,
  SITE_SCOPE_AUTH_SUCCESS,
  SITE_SCOPE_AUTH_FAIL,
  SITE_SCOPE_CHECK_REQUEST,
  SITE_SCOPE_CHECK_SUCCESS,
  SITE_SCOPE_CHECK_FAIL,
  SITE_SCOPE_AUTH_CLEAR,
  SITE_SCOPE_AUTH_SHOW_MODAL,
  SITE_SCOPE_AUTH_HIDE_MODAL,
} from './actions';

const initialState = {
  // Authentication state
  authenticated: false,
  token: null,
  requiresAuthentication: false,

  // UI state
  showModal: false,
  currentSiteScope: null,

  // Loading and error states
  loading: false,
  checking: false,
  error: null,
};

export default function siteScopeAuthReducer(state = initialState, action) {
  switch (action.type) {
    case SITE_SCOPE_AUTH_REQUEST:
      return {
        ...state,
        loading: true,
        error: null,
      };

    case SITE_SCOPE_AUTH_SUCCESS:
      return {
        ...state,
        loading: false,
        authenticated: true,
        token: action.payload.token,
        currentSiteScope: action.payload.siteScope,
        error: null,
      };

    case SITE_SCOPE_AUTH_FAIL:
      return {
        ...state,
        loading: false,
        authenticated: false,
        token: null,
        error: action.payload.error,
      };

    case SITE_SCOPE_CHECK_REQUEST:
      return {
        ...state,
        checking: true,
        error: null,
      };

    case SITE_SCOPE_CHECK_SUCCESS:
      return {
        ...state,
        checking: false,
        requiresAuthentication: action.payload.requiresAuthentication,
        authenticated: action.payload.authenticated,
        currentSiteScope: action.payload.siteScope,
        error: null,
      };

    case SITE_SCOPE_CHECK_FAIL:
      return {
        ...state,
        checking: false,
        error: action.payload.error,
      };

    case SITE_SCOPE_AUTH_CLEAR:
      return {
        ...state,
        error: null,
      };

    case SITE_SCOPE_AUTH_SHOW_MODAL:
      return {
        ...state,
        showModal: true,
        currentSiteScope: action.payload.siteScope,
      };

    case SITE_SCOPE_AUTH_HIDE_MODAL:
      return {
        ...state,
        showModal: false,
        error: null,
      };

    default:
      return state;
  }
}
