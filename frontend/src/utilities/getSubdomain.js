import { PORT, isProd } from '../state/utils/api';
import { getRouterParam } from './routeParams';

export const getSubdomain = () => {
  const host = isProd
    ? PORT.replace(/(^http(s?):\/\/)|(\.com)$/g, '')
    : `localhost:${window.location.port}`;
  if (window.location.host === '52.7.28.202') return false;
  let subdomain = window.location.host.split('.')[0].replace(host, '');
  if (!subdomain || subdomain === 'www') {
    subdomain = getRouterParam('site_scope');
  }
  return subdomain;
};

/**
 * @type {String} runs once on app init.
 */
export const subdomain = getSubdomain();
