import { NextResponse } from 'next/server';
import { PORT } from 'state/utils/api';
import { getSubdomainFromURL } from 'utilities/getSubdomain';
import type { NextRequest } from 'next/server';

const PUBLIC_FILE = /\.(.*)$/;

export function middleware(request: NextRequest) {
  // Only when the subdomain is set and the path is /, redirect to the map
  if (!!getSubdomainFromURL(PORT) && request.nextUrl.pathname === '/') {
    return NextResponse.redirect(new URL('/map', request.url));
  }
  // Only when the subdomain is set do not allow access
  if (!!getSubdomainFromURL(PORT)) return NextResponse.redirect(new URL('/404', request.url));

  // Avoid adding locale prefixes to api or public files
  if (
    request.nextUrl.pathname.startsWith('/_next') ||
    request.nextUrl.pathname.includes('/api/') ||
    PUBLIC_FILE.test(request.nextUrl.pathname)
  ) {
    return;
  }

  // Set the default locale (en) as a prefix if we don't have a locale in the url
  if (request.nextUrl.locale === 'default') {
    const locale = request.cookies.get('NEXT_LOCALE') || 'en';

    return NextResponse.redirect(
      new URL(`/${locale}${request.nextUrl.pathname}${request.nextUrl.search}`, request.url),
    );
  }
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
