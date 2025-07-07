import type { AxiosRequestConfig, Method } from 'axios';
import axios from 'axios';
import type { ThunkDispatch } from 'redux-thunk';
import type { schema } from 'normalizr';

import { merge } from 'utilities/helpers';
import { subdomain } from 'utilities/getSubdomain';

export const PORT = process.env.NEXT_PUBLIC_API_HOST;

const defaultConfig = {
  baseURL: `${PORT}/api`,
  headers: {
    Accept: 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/json',
  },
};

let axiosInstance = axios.create(defaultConfig);

// Function to get site scope token from localStorage
const getSiteScopeToken = (siteScope = subdomain) => {
  if (typeof window !== 'undefined') {
    return localStorage.getItem(`site_scope_token_${siteScope}`);
  }
  return null;
};

export const updateApi = (config: AxiosRequestConfig) => {
  axiosInstance = axios.create(merge(defaultConfig, config));
};

type ApiAction = {
  REQUEST: string;
  SUCCESS: string;
  FAIL: string;
};

export const createApiAction = (name = ''): ApiAction => {
  const prefix = name.split('/').join(' / ');

  return {
    REQUEST: `${prefix} / REQUEST`,
    SUCCESS: `${prefix} / SUCCESS`,
    FAIL: `${prefix} / FAIL`,
  };
};

export const makeRequest = (method: Method, url: string, options: AxiosRequestConfig = {}) => {
  const headers = { ...axiosInstance.defaults.headers, ...options.headers };

  // Add site scope token if available and this is a site-specific request
  const siteScope = options.params?.site_scope || subdomain;
  const siteScopeToken = getSiteScopeToken(siteScope);

  if (siteScopeToken) {
    headers['Site-Scope-Token'] = siteScopeToken;
  }

  return axiosInstance({
    ...options,
    method,
    url,
    headers,
  }).catch((error) => {
    // Check if this is a site scope authentication error
    if (
      error.response?.status === 401 &&
      error.response?.data?.errors?.[0]?.meta?.requires_authentication
    ) {
      // This is a site scope authentication error
      // Clear the potentially invalid token
      if (siteScopeToken && typeof window !== 'undefined') {
        localStorage.removeItem(`site_scope_token_${siteScope}`);
      }
    }

    return error.response
      ? Promise.reject({
          error: true,
          ...error.response,
        })
      : Promise.reject({ error: error.message });
  });
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Handler = (url: string, config: AxiosRequestConfig) => Promise<any>;
type Handlers = {
  get: Handler;
  post: Handler;
  put: Handler;
  patch: Handler;
  del: Handler;
};

export const get: Handler = (url, config) => makeRequest('get', url, config);
export const post: Handler = (url, config) => makeRequest('post', url, config);
export const put: Handler = (url, config) => makeRequest('put', url, config);
export const patch: Handler = (url, config) => makeRequest('patch', url, config);
export const del: Handler = (url, config) => makeRequest('delete', url, config);
export const requestHandlers: Handlers = { get, post, put, patch, del };

type Callback = (
  requestHandlers: Handlers,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  dispatch: ThunkDispatch<unknown, unknown, any>,
  getState: () => unknown,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
) => Promise<any>;

type ApiMeta = {
  schema?: schema.Entity | schema.Array;
  includedSchema?: schema.Entity | schema.Array | 'union';
};

/**
 * Redux API helper for request -> success/fail flow
 * @param {ApiAction} apiAction - can be created using `createApiAction`
 * @param {Callback} cb - callback which executes requests
 *
 * @returns {ThunkAction} thunk, which executes provided promise and binds three dispatches for request, success and fail phase
 */
export default function api(apiAction: ApiAction, cb: Callback, meta: ApiMeta) {
  return (dispatch, getState) => {
    dispatch({ type: apiAction.REQUEST, meta });

    return cb(requestHandlers, dispatch, getState)
      .then(({ data, status, headers }) => {
        dispatch({
          type: apiAction.SUCCESS,
          payload: {
            ...(data.data ? data : { data }),
            status,
            headers,
          },
          meta,
        });
      })
      .catch((error) => {
        if (error.error) {
          dispatch({
            type: apiAction.FAIL,
            meta,
          });
        } else {
          // eslint-disable-next-line no-console
          console.error(error);
        }
      });
  };
}
