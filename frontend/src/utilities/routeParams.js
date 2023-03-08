import history from '../history';

/**
 * @param  {string} param name of query param you want to set
 * @param  {string} value value to set
 *
 * @returns  {void}
 */
export const setRouterParam = (param, value) => {
  const {
    location: { pathname, search },
  } = history;

  const params = new URLSearchParams(search.slice(1));
  if (value) {
    params.set(param, value);
  } else params.delete(param);

  history.replace({
    pathname,
    search: params.toString(),
  });
};

/**
 * @param  {string} param name of query param you want to set
 * @param  {Function} parser function, that receives value as argument
 *
 * @returns  {any} value
 */
export const getRouterParam = (param, parser) => {
  const {
    location: { search },
  } = history;

  const params = new URLSearchParams(search.slice(1));
  const result = params.get(param);

  if (parser) return parser(result);
  return result;
};

export const useRouterParams = () => {
  const {
    location: { pathname, search },
  } = history;

  const params = new URLSearchParams(search.slice(1));

  const getParam = (param, parser) => {
    const result = params.get(param);

    if (parser) return parser(result);
    return result;
  };

  const setParam = (param, value) => {
    params.set(param, value);

    history.replace({
      pathname,
      search: params.toString(),
    });
  };

  const removeParam = (param) => {
    params.delete(param);

    history.replace({
      pathname,
      search: params.toString(),
    });
  };

  return { getParam, setParam, removeParam };
};
