import { isProd } from '../state/utils/api';
import { getRouterParam } from './routeParams';

export const getSubdomainFromURL = (url: string): string => {
  // Site scope depends on the domain set in the API
  const host = url.replace(/(^http(s?):\/\/)|(\.com)$/g, '');
  const subdomain = host.split('.')[0];
  // If no subdomain is set or we're in localhost, return null
  if (
    !subdomain ||
    // Happens when loading https://www.resilienceatlas.org
    subdomain === 'www' ||
    // Happens when loading https://resilienceatlas.org
    subdomain === 'resilienceatlas' ||
    // Happens when loading https://staging.resilienceatlas.org
    subdomain === 'staging' ||
    // Happens when loading http://localhost:3000 (for example)
    subdomain.startsWith('localhost')
  ) {
    return null;
  }
  return subdomain;
};

export const getSubdomain = (): string => {
  // Only works on client side
  if (typeof window === 'undefined') return null;
  // Pass site_scope param in the URL to simulate a subdomain, only for development purposes
  const siteScope = getRouterParam('site_scope');
  if (siteScope && !isProd) return siteScope;
  // Site scope depends on the domain set in the API
  const subdomain = getSubdomainFromURL(window.location.hostname);
  return subdomain;
};

/**
 * @type {String} runs once on app init.
 */
export const subdomain: string = getSubdomain();
