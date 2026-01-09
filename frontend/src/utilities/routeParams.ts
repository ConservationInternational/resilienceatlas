'use client';

import { useRouter } from 'next/router';
import { useCallback, useRef, useEffect } from 'react';

// Re-export getRouterParam for backward compatibility
export { getRouterParam } from './urlParams';

export const useRouterParams = () => {
  const router = useRouter();
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const isNavigatingRef = useRef(false);

  const { pathname } = router;
  const params = { ...router.query };

  // Clear any pending debounced updates when navigation starts
  // This prevents the debounced router.replace from interfering with Link navigation
  useEffect(() => {
    const handleRouteChangeStart = () => {
      isNavigatingRef.current = true;
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };

    const handleRouteChangeComplete = () => {
      isNavigatingRef.current = false;
    };

    const handleRouteChangeError = () => {
      isNavigatingRef.current = false;
    };

    router.events.on('routeChangeStart', handleRouteChangeStart);
    router.events.on('routeChangeComplete', handleRouteChangeComplete);
    router.events.on('routeChangeError', handleRouteChangeError);

    return () => {
      router.events.off('routeChangeStart', handleRouteChangeStart);
      router.events.off('routeChangeComplete', handleRouteChangeComplete);
      router.events.off('routeChangeError', handleRouteChangeError);
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };
  }, [router.events]);

  const getParam = (param, parser) => {
    const result = params[param];
    if (parser) return parser(result);
    return result;
  };

  const debouncedReplace = useCallback(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (newParams: Record<string, any>) => {
      // Don't schedule updates if we're already navigating
      if (isNavigatingRef.current) {
        return;
      }

      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }

      timeoutRef.current = setTimeout(() => {
        // Double-check that we're not navigating and still on the same page
        if (!isNavigatingRef.current && router.pathname === pathname) {
          router.replace(
            {
              pathname,
              query: newParams,
            },
            undefined,
            { shallow: true },
          );
        }
      }, 100); // 100ms debounce
    },
    [router, pathname],
  );

  const setParam = (param: string, value: string): void => {
    params[param] = value;
    debouncedReplace({ ...params });
  };

  const removeParam = (param) => {
    delete params[param];
    debouncedReplace({ ...params });
  };

  return { getParam, setParam, removeParam };
};
