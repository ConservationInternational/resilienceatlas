import { createReducer } from '../../utils';
import { LOAD } from './actions';

const initialState = {
  has_analysis: false,
  predictive_model: false,
  name: '',
  subdomain: '',
  color: '#0089cc',
  header_theme: '',
  latitude: NaN,
  longitude: NaN,
  zoom_level: NaN,
  linkback_text: null,
  linkback_url: null,
  header_color: null,
  logo_url: '',

  loading: false,
  loaded: false,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    error: null,
    loading: true,
  }),

  [LOAD.SUCCESS]: (state, { payload }) => {
    const data = payload.entities.site_scopes[payload.result];

    return {
      ...state,
      ...data,
      logo_url: data.logo_url || '/images/logo-ci.png',

      loading: false,
      loaded: true,
    };
  },

  [LOAD.FAIL]: (state, { error }) => ({
    ...initialState,
    logo_url: '/images/logo-ci.png',
    loading: false,
    error,
  }),
});
