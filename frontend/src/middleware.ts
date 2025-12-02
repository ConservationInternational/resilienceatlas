import { NextResponse } from 'next/server';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host');
  const { pathname, searchParams } = request.nextUrl;

  // Check for site_scope parameter for development/testing
  const siteScope = searchParams.get('site_scope');

  // Get subdomain from the current host, or use site_scope for development/testing
  let subdomain = getSubdomainFromURL(host);

  // In development/test, use site_scope parameter to simulate subdomain
  // Note: In middleware, NODE_ENV might not always be reliable, so we also check for common test/dev hosts
  const isDevOrTest =
    process.env.NODE_ENV === 'development' ||
    process.env.NODE_ENV === 'test' ||
    !host ||
    host.includes('localhost') ||
    host.includes('frontend-test') ||
    host.includes('frontend-dev');

  if (siteScope && isDevOrTest) {
    subdomain = siteScope;
  }

  // Log for debugging in development or test
  if (isDevOrTest) {
    // eslint-disable-next-line no-console
    console.log(
      `Middleware: host=${host}, pathname=${pathname}, subdomain=${subdomain}, siteScope=${siteScope}, env=${process.env.NODE_ENV}`,
    );
  }

  // If we have a subdomain and the path is /, redirect to the map
  if (subdomain && pathname === '/') {
    const mapUrl = new URL('/map', request.url);
    // Preserve site_scope parameter in redirect for development/testing
    if (siteScope) {
      mapUrl.searchParams.set('site_scope', siteScope);
    }
    return NextResponse.redirect(mapUrl);
  }

  // If we have a subdomain, only allow access to specific routes
  if (subdomain && !isAllowedPath(pathname)) {
    // For subdomains, redirect non-allowed pages to 404
    const notFoundUrl = new URL('/404', request.url);
    // Preserve site_scope parameter in redirect for development/testing
    if (siteScope) {
      notFoundUrl.searchParams.set('site_scope', siteScope);
    }
    return NextResponse.redirect(notFoundUrl);
  }

  // Continue with the request
  return NextResponse.next();
}

/**
 * Check if a path is allowed for subdomain access
 */
function isAllowedPath(pathname: string): boolean {
  const allowedPaths = ['/embed', '/map', '/_next', '/api', '/404', '/favicon.ico', '/robots.txt'];

  return allowedPaths.some((path) => pathname.startsWith(path));
}

// See "Matching Paths" below to learn more
export const config = {
  matcher: [
    '/',
    '/about',
    '/embed/:path*',
    '/journeys',
    '/journeys/:id/step/:path*',
    '/login',
    '/map',
    '/me',
    '/profile-settings',
    '/register',
    '/shinny-app',
  ],
};
