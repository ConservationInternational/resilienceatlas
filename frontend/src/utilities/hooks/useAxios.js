import { useReducer, useEffect } from 'react';
import axios from 'axios';
import createReducer from '../../state/utils/createReducer';
import { createApiAction } from '../../state/utils/api';

const FETCH = createApiAction('FETCH');

const initialState = {
  loading: false,
  loaded: false,
  error: null,
  data: null,
};

const fetchReducer = createReducer(initialState)({
  [FETCH.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),

  [FETCH.SUCCESS]: (state, { data }) => ({
    ...state,
    loading: false,
    loaded: true,
    data,
  }),

  [FETCH.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    loaded: true,
    error,
  }),
});
/**
 * @param  {AxiosRequestConfig} config
 * @param  {array} deps=[] React useEffect dependencies to execute fetch on
 * @param  {Function} ParseData data parser function
 *
 * @returns {array} [data, loading, lodaed, error]
 */
export const useAxios = (config, deps, parseData) => {
  const [state, dispatch] = useReducer(fetchReducer, initialState);

  useEffect(() => {
    const abortController = new AbortController();
    dispatch({ type: FETCH.REQUEST });

    axios({ ...config, signal: abortController.signal })
      .then(({ data }) =>
        dispatch({
          type: FETCH.SUCCESS,
          data: parseData ? parseData(data) : data,
        }),
      )
      .catch((error) => {
        // Silently ignore canceled requests
        if (
          axios.isCancel(error) ||
          error.code === 'ERR_CANCELED' ||
          error.name === 'CanceledError'
        ) {
          return;
        }
        // eslint-disable-next-line no-console
        console.warn(error);
        dispatch({ type: FETCH.FAIL, error });
      });

    return () => {
      abortController.abort();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [config, parseData, ...deps]);

  return [state.data, state.loading, state.loaded, state.error];
};
