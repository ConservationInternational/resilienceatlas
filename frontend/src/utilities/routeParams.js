// import history from '../history';
import Router from 'next/router';

/**
 * @param  {string} param name of query param you want to set
 * @param  {string} value value to set
 *
 * @returns  {void}
 */
export const setRouterParam = (param, value) => {
  // const {
  //   location: { pathname, search },
  // } = history;

  // const params = new URLSearchParams(search.slice(1));
  // if (value) {
  //   params.set(param, value);
  // } else params.delete(param);

  // history.replace({
  //   pathname,
  //   search: params.toString(),
  // });
  Router.push({
    query: {
      [param]: value,
    },
  });
};

/**
 * @param  {string} param name of query param you want to set
 * @param  {Function} parser function, that receives value as argument
 *
 * @returns  {any} value
 */
export const getRouterParam = (param, parser) => {
  // const {
  //   location: { search },
  // } = history;

  // const params = new URLSearchParams(search.slice(1));
  // const result = params.get(param);

  // if (parser) return parser(result);
  // return result;
  const query = {};
  if (parser && typeof parser === 'function') return parser(query[param] || null);
  return query[param];
};

export const useRouterParams = () => {
  const router = useRouter();
  // const {
  //   location: { pathname, search },
  // } = history;

  const params = { ...router.query };

  const getParam = (param, parser) => {
    const result = params[param];
    if (parser) return parser(result);
    return result;
  };

  const setParam = (param, value) => {
    params.set(param, value);

    router.replace({
      pathname,
      query: params,
    });
  };

  const removeParam = (param) => {
    params.delete(param);

    router.replace({
      pathname,
      query: params,
    });
  };

  return { getParam, setParam, removeParam };
};
