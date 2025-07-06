export const getSiteScopeAuthState = (state) => state.siteScopeAuth;

export const isSiteScopeAuthenticated = (state) => getSiteScopeAuthState(state).authenticated;

export const siteScopeRequiresAuthentication = (state) =>
  getSiteScopeAuthState(state).requiresAuthentication;

export const getSiteScopeAuthToken = (state) => getSiteScopeAuthState(state).token;

export const getSiteScopeAuthError = (state) => getSiteScopeAuthState(state).error;

export const isSiteScopeAuthLoading = (state) => getSiteScopeAuthState(state).loading;

export const isSiteScopeAuthChecking = (state) => getSiteScopeAuthState(state).checking;

export const shouldShowSiteScopeAuthModal = (state) => getSiteScopeAuthState(state).showModal;

export const getCurrentSiteScope = (state) => getSiteScopeAuthState(state).currentSiteScope;
