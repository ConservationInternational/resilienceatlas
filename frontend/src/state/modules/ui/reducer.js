import { TABS } from '@components/Sidebar';
import { getRouterParam } from '@utilities';
import { createReducer } from '../../utils';
import { TOGGLE_SIDEBAR, TOGGLE_ANALYSIS_PANEL, SET_TAB } from './actions';

const geojson = getRouterParam('geojson');
const iso = getRouterParam('iso');
const persistedTab = getRouterParam('tab');
const model = getRouterParam('model');

const initialState = {
  sidebar: true,
  analysisPanel: !!(geojson || iso),
  tab: persistedTab || (model ? TABS.MODEL : TABS.LAYERS),
};

export default createReducer(initialState)({
  [TOGGLE_SIDEBAR]: state => ({
    ...state,
    sidebar: !state.sidebar,
  }),

  [TOGGLE_ANALYSIS_PANEL]: state => ({
    ...state,
    analysisPanel: !state.analysisPanel,
  }),

  [SET_TAB]: (state, { tab }) => ({
    ...state,
    tab,
  }),
});
