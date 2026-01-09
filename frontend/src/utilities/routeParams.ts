'use client';

import { useRouter } from 'next/router';
import { useCallback, useRef, useEffect } from 'react';

// Re-export getRouterParam for backward compatibility
export { getRouterParam } from './urlParams';

export const useRouterParams = () => {
  const router = useRouter();
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  const { pathname } = router;
  const params = { ...router.query };

  // Clear any pending debounced updates when pathname changes or component unmounts
  // This prevents the debounced router.replace from interfering with Link navigation
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };
  }, [pathname]);

  const getParam = (param, parser) => {
    const result = params[param];
    if (parser) return parser(result);
    return result;
  };

  const debouncedReplace = useCallback(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (newParams: Record<string, any>) => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }

      timeoutRef.current = setTimeout(() => {
        // Double-check that we're still on the same page before replacing
        // This prevents navigating back to the old page if user clicked a link
        if (router.pathname === pathname) {
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
