import { useEffect } from 'react';
import { useCookiesConsent } from 'utilities/hooks/useCookiesConsent';

// log the pageView with their URL
export const pageView = (url) => {
  window.gtag('config', process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS, {
    page_path: url,
  });
};

// log specific events happening.
export const event = ({ action, params }) => {
  window.gtag('event', action, params);
};

export const useInitGAScript = () => {
  const { allowCookies } = useCookiesConsent();
  useEffect(() => {
    const head = document.head;
    if (allowCookies && head) {
      const existingGaScript = document.getElementById('ga-script');
      if (!existingGaScript) {
        const gaScript = document.createElement('script');
        gaScript.id = 'ga-script';
        gaScript.src = `https://www.googletagmanager.com/gtag/js?id=${process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS}`;
        gaScript.async = true;

        head.appendChild(gaScript);
      }

      const existingGTagScript = document.getElementById('gtag-script');
      if (!existingGTagScript) {
        const gtagScript = document.createElement('script');
        gtagScript.id = 'gtag-script';
        gtagScript.innerHTML = `window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS}', {
            page_path: window.location.pathname,
          });`;
        head.appendChild(gtagScript);
      }
    }
  }, [allowCookies]);
};
