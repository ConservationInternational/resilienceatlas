import axios, { AxiosRequestConfig } from 'axios';
import { ThunkAction, ThunkDispatch } from 'redux-thunk';
import { schema } from 'normalizr';

import { merge } from '@utilities/helpers';

export const isProd = process.env.NODE_ENV === 'production';

export const PORT = process.env.REACT_APP_API_HOST;
// uncomment this line to see map layers quickly for local testing
// export const PORT = 'https://staging.resilienceatlas.org';

const defaultConfig = {
  baseURL: `${PORT}/api`,
  headers: {
    Accept: 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/json',
  },
};

let axiosInstance = axios.create(defaultConfig);

export const updateApi = (config: AxiosRequestConfig) => {
  axiosInstance = axios.create(merge(defaultConfig, config));
};

type ApiAction = {
  REQUEST: String,
  SUCCESS: String,
  FAIL: String,
};

export const createApiAction = (name = ''): ApiAction => {
  const prefix = name.split('/').join(' / ');

  return {
    REQUEST: `${prefix} / REQUEST`,
    SUCCESS: `${prefix} / SUCCESS`,
    FAIL: `${prefix} / FAIL`,
  };
};

export const makeRequest = (
  method: string,
  url: string,
  options: AxiosRequestConfig = {},
) => {
  const headers = { ...axiosInstance.defaults.headers, ...options.headers };

  return axiosInstance({
    ...options,
    method,
    url,
    headers,
  }).catch(error =>
    error.response
      ? Promise.reject({
          error: true,
          ...error.response,
        })
      : Promise.reject({ error: error.message }),
  );
};

type Handler = (url: String, config: AxiosRequestConfig) => Promise<any>;
type Handlers = {
  get: Handler,
  post: Handler,
  put: Handler,
  patch: Handler,
  del: Handler,
};

export const get: Handler = (url, config) => makeRequest('get', url, config);
export const post: Handler = (url, config) => makeRequest('post', url, config);
export const put: Handler = (url, config) => makeRequest('put', url, config);
export const patch: Handler = (url, config) =>
  makeRequest('patch', url, config);
export const del: Handler = (url, config) => makeRequest('delete', url, config);
export const requestHandlers: Handlers = { get, post, put, patch, del };

type Callback = (
  requestHandlers: Handlers,
  dispatch: ThunkDispatch,
  getState: Function,
) => Promise<any>;

type ApiMeta = {
  schema?: schema.Entity | schema.Array,
  includedSchema?: schema.Entity | schema.Array | 'union',
};

/**
 * Redux API helper for request -> success/fail flow
 * @param {ApiAction} apiAction - can be created using `createApiAction`
 * @param {Callback} cb - callback which executes requests
 *
 * @returns {ThunkAction} thunk, which executes provided promise and binds three dispatches for request, success and fail phase
 */
export default function api(
  apiAction: ApiAction,
  cb: Callback,
  meta: ApiMeta,
): ThunkAction {
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
      .catch(error => {
        if (error.error) {
          dispatch({
            type: apiAction.FAIL,
            meta,
          });
        } else {
          console.error(error);
        }
      });
  };
}
