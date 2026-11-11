import { getApiBaseUrl } from './environment';
import { subdomain } from './getSubdomain';

export const scopeDataUrl = (url: string): string => {
  const apiOrigin = new URL(getApiBaseUrl()).origin;
  const parsed = new URL(url, getApiBaseUrl());
  if (parsed.origin !== apiOrigin || !parsed.pathname.startsWith('/api/')) return url;

  if (subdomain && !parsed.searchParams.has('site_scope')) {
    parsed.searchParams.set('site_scope', subdomain);
  }
  if (typeof window !== 'undefined') {
    const scope = parsed.searchParams.get('site_scope');
    const token = scope ? sessionStorage.getItem(`site_scope_token_${scope}`) : null;
    if (token && !parsed.searchParams.has('site_scope_token')) {
      parsed.searchParams.set('site_scope_token', token);
    }
  }
  // Keep tile coordinate and timeline placeholders intact.
  return parsed.toString().replace(/%7B/gi, '{').replace(/%7D/gi, '}');
};
