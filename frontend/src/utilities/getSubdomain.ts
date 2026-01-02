import { getRouterParam } from './routeParams';
import { isDevelopment } from './environment';

export const getSubdomainFromURL = (url: string): string | null => {
  // Site scope depends on the domain set in the API
  let host = url.replace(/(^http(s?):\/\/)|(\.com)$/g, '');

  // Remove port number if present (e.g., frontend-test:3000 -> frontend-test)
  host = host.split(':')[0];

  const parts = host.split('.');

  // Handle different domain structures:
  // For staging.resilienceatlas.org -> parts = ['staging', 'resilienceatlas', 'org']
  // For subdomain.staging.resilienceatlas.org -> parts = ['subdomain', 'staging', 'resilienceatlas', 'org']
  // For resilienceatlas.org -> parts = ['resilienceatlas', 'org']
  // For subdomain.resilienceatlas.org -> parts = ['subdomain', 'resilienceatlas', 'org']

  let subdomain: string;

  if (parts.length >= 4 && parts[1] === 'staging' && parts[2] === 'resilienceatlas') {
    // Format: subdomain.staging.resilienceatlas.org
    subdomain = parts[0];
  } else if (parts.length >= 3 && parts[1] === 'resilienceatlas') {
    // Format: subdomain.resilienceatlas.org
    subdomain = parts[0];
  } else {
    // Single domain or localhost
    subdomain = parts[0];
  }

  // If no subdomain is set or we're in localhost, return null
  if (
    !subdomain ||
    // Happens when loading https://www.resilienceatlas.org or https://www.staging.resilienceatlas.org
    subdomain === 'www' ||
    // Happens when loading https://resilienceatlas.org
    subdomain === 'resilienceatlas' ||
    // Happens when loading https://staging.resilienceatlas.org
    subdomain === 'staging' ||
    // Happens when loading https://app.resilienceatlas.org or https://app.staging.resilienceatlas.org
    subdomain === 'app' ||
    // Happens when loading http://localhost:3000 (for example)
    subdomain.startsWith('localhost') ||
    // Happens when loading in Docker environments (test/dev)
    subdomain === 'frontend-test' ||
    subdomain === 'frontend-app' ||
    subdomain === 'frontend-dev' ||
    subdomain === 'frontend' ||
    // Docker service names in different environments
    subdomain.startsWith('frontend-') ||
    // Other common localhost variations
    subdomain === '127' ||
    subdomain.startsWith('192.168') ||
    subdomain.startsWith('10.0') ||
    subdomain.startsWith('172.')
  ) {
    return null;
  }
  return subdomain;
};

/**
 * Check if we're in a test environment where site_scope override should be allowed
 */
const isTestEnvironment = (): boolean => {
  if (typeof window === 'undefined') return false;

  const hostname = window.location.hostname;
  // Allow site_scope override in Docker test environments
  return (
    hostname === 'frontend-test' ||
    hostname.startsWith('frontend-test') ||
    hostname === 'localhost' ||
    hostname === '127.0.0.1'
  );
};

export const getSubdomain = (): string | null => {
  // Only works on client side
  if (typeof window === 'undefined') return null;

  // Pass site_scope param in the URL to simulate a subdomain
  // Allowed in development mode OR in test environments (Docker)
  const siteScope = getRouterParam('site_scope');
  if (siteScope && (isDevelopment() || isTestEnvironment())) return siteScope;

  // Site scope depends on the domain set in the API
  const subdomain = getSubdomainFromURL(window.location.hostname);
  return subdomain;
};

/**
 * @type {String | null} runs once on app init.
 */
export const subdomain: string | null = getSubdomain();
