/**
 * Get param from URL
 * @param  {string} param name of query param you want to set
 * @param  {Function} parser function, that receives value as argument
 *
 * @returns  {string}
 *
 * NOTE: Only works on client side - uses window.location
 */
export const getRouterParam = (param: string, parser?: (a: string) => string): string => {
  if (typeof window === 'undefined') return '';

  const params = new URLSearchParams(window.location.search.slice(1));
  const result = params.get(param);
  if (parser && typeof parser === 'function') return parser(result);
  return result;
};
