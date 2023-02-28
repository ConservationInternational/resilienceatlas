export const TOGGLE_SIDEBAR = 'ui / SIDEBAR / TOGGLE';
export const SET_TAB = 'ui / SIDEBAR / SET_TAB';
export const TOGGLE_ANALYSIS_PANEL = 'ui / ANALYSIS_PANEL / TOGGLE';

export const toggleSidebar = () => ({
  type: TOGGLE_SIDEBAR,
});

export const setTab = tab => ({
  type: SET_TAB,
  tab,
});

export const toggleAnalysis = () => ({
  type: TOGGLE_ANALYSIS_PANEL,
});
