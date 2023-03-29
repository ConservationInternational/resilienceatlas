import type { FC } from 'react';
import { useCallback } from 'react';

import { useCookiesConsent } from 'utilities/hooks/useCookiesConsent';
import { T } from '@transifex/react';

const NoticeContent: FC = ({}) => {
  const { updateConsent } = useCookiesConsent();
  const onAcceptCookies = useCallback(() => updateConsent(true, +new Date()), [updateConsent]);
  const onRefuseCookies = useCallback(() => updateConsent(false, +new Date()), [updateConsent]);

  return (
    <div className="m-privacy-banner">
      <p className="disclaimer">
        <T
          _str="We use cookies for analytics, personalization, and marketing purposes. Only essential
        cookies are active by default to ensure you get the best experience. Please read our {cookiePolicy} to learn more."
          _comment="We use cookies for analytics, personalization, and marketing purposes. Only essential
        cookies are active by default to ensure you get the best experience. Please read our {cookiePolicy} to learn more."
          _cookiePolicy={
            <a
              href="https://www.conservation.org/about/our-policies/cookie-policy"
              title="cookie policy"
              target="_blank"
              rel="noreferrer"
              className="link"
            >
              <T
                _str="Cookie Policy"
                _comment="We use cookies for analytics, personalization, and marketing purposes. Only essential
        cookies are active by default to ensure you get the best experience. Please read our {cookiePolicy} to learn more."
              />
            </a>
          }
        />
      </p>
      <div className="buttons">
        <button
          type="button"
          data-test-id="refuse"
          className="btn btn-primary -sm -inverted-color"
          onClick={onRefuseCookies}
        >
          <T _str="Reject non-essential" _comment="Reject non-essential cookies" />
        </button>
        <button
          type="button"
          data-test-id="accept"
          className="btn btn-primary -sm -inverted-color"
          onClick={onAcceptCookies}
        >
          <T _str="Accept" _comment="Accept cookie banner" />
        </button>
      </div>
    </div>
  );
};

export default NoticeContent;
