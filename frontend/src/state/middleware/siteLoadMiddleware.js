import { LOAD } from '../modules/site/actions';
import { showModal, checkSiteScopeAccess } from '../modules/site_scope_auth/actions';
import { subdomain } from 'utilities/getSubdomain';

/**
 * Middleware to handle site scope authentication after site loading
 */
const siteLoadMiddleware =
  ({ dispatch, getState }) =>
  (next) =>
  (action) => {
    const result = next(action);

    // Check if this is a successful site load
    if (action.type === LOAD.SUCCESS) {
      const { payload } = action;
      const data = payload.entities.site_scopes[payload.result];

      // If the site scope is password protected, check access
      if (data.password_protected) {
        dispatch(checkSiteScopeAccess(subdomain));
      }
    }

    return result;
  };

export default siteLoadMiddleware;
