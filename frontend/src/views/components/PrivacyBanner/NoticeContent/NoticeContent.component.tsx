import type { FC } from 'react';
import { useCallback } from 'react';

import { useCookiesConsent } from 'utilities/hooks/useCookiesConsent';

const NoticeContent: FC = ({}) => {
  const { updateConsent } = useCookiesConsent();
  const onAcceptCookies = useCallback(() => updateConsent(true, +new Date()), [updateConsent]);
  const onRefuseCookies = useCallback(() => updateConsent(false, +new Date()), [updateConsent]);

  return (
    <div className="m-privacy-banner">
      <p className="disclaimer">
        We use cookies for analytics, personalization, and marketing purposes. Only essential
        cookies are active by default to ensure you get the best experience. Please read our{' '}
        <a
          href="https://www.conservation.org/about/our-policies/cookie-policy"
          title="cookie policy"
          target="_blank"
          rel="noreferrer"
          className="link"
        >
          Cookie Policy
        </a>{' '}
        to learn more.
      </p>
      <div className="buttons">
        <button
          type="button"
          className="btn btn-primary -sm -inverted-color"
          onClick={onRefuseCookies}
        >
          Reject non-essential
        </button>
        <button
          type="button"
          className="btn btn-primary -sm -inverted-color"
          onClick={onAcceptCookies}
        >
          Accept
        </button>
      </div>
    </div>
  );
};

export default NoticeContent;
