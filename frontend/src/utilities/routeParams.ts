import { useRouter } from 'next/router';

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

  const { pathname } = router;
  const params = { ...router.query };

  const getParam = (param, parser) => {
    const result = params[param];
    if (parser) return parser(result);
    return result;
  };

  const setParam = (param, value) => {
    params[param] = value;

    router.replace(
      {
        pathname,
        query: params,
      },
      undefined,
      { shallow: true },
    );
  };

  const removeParam = (param) => {
    delete params[param];

    router.replace(
      {
        pathname,
        query: params,
      },
      undefined,
      { shallow: true },
    );
  };

  return { getParam, setParam, removeParam };
};
