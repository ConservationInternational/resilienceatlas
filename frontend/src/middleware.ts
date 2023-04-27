import { NextResponse } from 'next/server';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host');

  const { pathname } = request.nextUrl;
  // If we have a subdomain and the path is /, redirect to the map
  if (!!getSubdomainFromURL(host) && pathname === '/') {
    return NextResponse.redirect(new URL('/map', request.url));
  }
  // If we have a subdomain do not allow access to other pages other than embed
  if (!!getSubdomainFromURL(host) && !pathname.startsWith('/embed'))
    return NextResponse.redirect(new URL('/404', request.url));
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
