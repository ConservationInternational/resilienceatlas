import { showAuthModal, clearSiteScopeToken } from 'state/modules/site_scope_auth';
import { subdomain } from 'utilities/getSubdomain';

// Middleware to handle site scope authentication errors
export const siteScopeAuthMiddleware = (store) => (next) => (action) => {
  // Check if this is an API action with a 401 site scope error
  if (action.type && action.type.includes('FAIL') && action.error) {
    const error = action.payload || action.error;

    // Check if this is a site scope authentication error
    if (error.status === 401 && error.data?.errors?.[0]?.meta?.requires_authentication) {
      const siteScope = error.data.errors[0].meta.site_scope || subdomain;

      // Clear the invalid token
      clearSiteScopeToken(siteScope);

      // Show the authentication modal
      store.dispatch(showAuthModal(siteScope));
    }
  }

  return next(action);
};

export default siteScopeAuthMiddleware;
