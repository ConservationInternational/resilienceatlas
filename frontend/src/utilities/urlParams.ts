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

  // Return empty/null result early to avoid passing empty strings to parsers like JSON.parse
  if (result === null || result === '') {
    return result;
  }

  if (parser && typeof parser === 'function') return parser(result);
  return result;
};
