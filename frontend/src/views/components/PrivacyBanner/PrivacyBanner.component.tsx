import type { FC } from 'react';
import { useState, useEffect } from 'react';

import { useCookiesConsent } from 'utilities/hooks/useCookiesConsent';
import { useSiteScopeContentReady } from 'utilities/hooks/useSiteScopeContentReady';

import NoticeContent from './NoticeContent';

export const PrivacyNotice: FC = () => {
  const [mounted, setMounted] = useState(false);

  const { consentDate, initialized } = useCookiesConsent();
  const siteScopeContentReady = useSiteScopeContentReady();
  // When the component is mounted, we store that information
  useEffect(() => {
    setMounted(true);
  }, [setMounted]);

  // We avoid a flash of the privacy notice by not displaying it  until the component has mounted
  if (!mounted || !initialized) {
    return null;
  }

  if (!siteScopeContentReady) {
    return null;
  }

  // Whether the user has allowed the cookies or not, the notice should not be displayed again
  if (consentDate) {
    return null;
  }

  return <NoticeContent />;
};

export default PrivacyNotice;
