import { NextResponse } from 'next/server';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host');
  const { pathname } = request.nextUrl;

  // Get subdomain from the current host
  const subdomain = getSubdomainFromURL(host);

  // Log for debugging in development
  if (process.env.NODE_ENV === 'development') {
    console.log(`Middleware: host=${host}, pathname=${pathname}, subdomain=${subdomain}`);
  }

  // If we have a subdomain and the path is /, redirect to the map
  if (subdomain && pathname === '/') {
    const mapUrl = new URL('/map', request.url);
    return NextResponse.redirect(mapUrl);
  }

  // If we have a subdomain, only allow access to specific routes
  if (subdomain && !isAllowedPath(pathname)) {
    // For subdomains, redirect non-allowed pages to 404
    const notFoundUrl = new URL('/404', request.url);
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
    '/me',
    '/profile-settings',
    '/register',
    '/shinny-app',
  ],
};
