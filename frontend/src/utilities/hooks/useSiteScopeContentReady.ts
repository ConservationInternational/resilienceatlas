import { useSelector } from 'react-redux';

import {
  isSiteScopeAuthenticated,
  isSiteScopeAuthChecking,
  siteScopeRequiresAuthentication,
} from 'state/modules/site_scope_auth';
import type { RootState } from 'state/types';

export const useSiteScopeContentReady = (): boolean => {
  const siteLoaded = useSelector((state: RootState) => state.site.loaded);
  const passwordProtected = useSelector((state: RootState) =>
    Boolean(state.site.password_protected),
  );
  const checking = useSelector(isSiteScopeAuthChecking);
  const requiresAuthentication = useSelector(siteScopeRequiresAuthentication);
  const authenticated = useSelector(isSiteScopeAuthenticated);

  if (!siteLoaded) {
    return false;
  }

  if (!passwordProtected) {
    return true;
  }

  if (checking) {
    return false;
  }

  if (!requiresAuthentication) {
    return true;
  }

  return authenticated;
};

export default useSiteScopeContentReady;
