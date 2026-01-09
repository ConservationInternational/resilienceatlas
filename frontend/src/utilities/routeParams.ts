'use client';

import { useRouter } from 'next/router';
import { useCallback, useRef } from 'react';

// Re-export getRouterParam for backward compatibility
export { getRouterParam } from './urlParams';

export const useRouterParams = () => {
  const router = useRouter();
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  const { pathname } = router;
  const params = { ...router.query };

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
        router.replace(
          {
            pathname,
            query: newParams,
          },
          undefined,
          { shallow: true },
        );
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
