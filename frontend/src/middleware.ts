import { NextResponse } from 'next/server';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host');

  // Only when the subdomain is set and the path is /, redirect to the map
  if (!!getSubdomainFromURL(host) && request.nextUrl.pathname === '/') {
    return NextResponse.redirect(new URL('/map', request.url));
  }
  // Only when the subdomain is set do not allow access
  if (!!getSubdomainFromURL(host)) return NextResponse.redirect(new URL('/404', request.url));
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
