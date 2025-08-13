import { useRouter } from 'next/router';
import { useCallback, useRef } from 'react';

/**
 * Get param fom URL
 * @param  {string} param name of query param you want to set
 * @param  {Function} parser function, that receives value as argument
 *
 * @returns  {string}
 *
 * NOTE: Only works on client side
 */
export const getRouterParam = (param: string, parser?: (a: string) => string): string => {
  if (typeof window === 'undefined') return '';

  const params = new URLSearchParams(window.location.search.slice(1));
  const result = params.get(param);
  if (parser && typeof parser === 'function') return parser(result);
  return result;
};

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
