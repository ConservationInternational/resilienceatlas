const { locales } = require('./locales.config.json');

const { NEXT_PUBLIC_TRANSIFEX_TOKEN, NEXT_PUBLIC_API_HOST } = process.env;

// Determine if we're in production based on API host
const isProduction = NEXT_PUBLIC_API_HOST && NEXT_PUBLIC_API_HOST.includes('resilienceatlas.org');
const isStaging = NEXT_PUBLIC_API_HOST && NEXT_PUBLIC_API_HOST.includes('staging');

/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  turbopack: {
    root: __dirname,
  },
  output: 'standalone',
  productionBrowserSourceMaps: true,
  poweredByHeader: false,
  // Enable trailing slash for better subdomain handling
  trailingSlash: false,
  // Disable static indicator to prevent HMR errors with isrManifest messages
  devIndicators: false,
  // Note: ESLint is now configured via eslint.config.mjs (ESLint 9 flat config)
  // The 'eslint' option was removed in Next.js 16. Use `npm run lint` directly.
  typescript: {
    // !! WARN !!
    // Dangerously allow production builds to successfully complete even if
    // your project has type errors.
    // !! WARN !!
    ignoreBuildErrors: true,
  },
  images: {
    // Allow Next.js <Image> to optimize images from the backend and CDN origins.
    remotePatterns: [
      { protocol: 'https', hostname: '**.resilienceatlas.org' },
      { protocol: 'https', hostname: '**.globalresiliencepartnership.org' },
      // Local development
      { protocol: 'http', hostname: 'localhost' },
      { protocol: 'http', hostname: 'backend' },
    ],
  },
  // Next.js 16+ uses experimental.serverActions instead of serverExternalPackages
  serverExternalPackages: [],
  async headers() {
    return [
      {
        // Apply security headers to all routes except admin-preview
        source: '/((?!admin-preview).*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
        ],
      },
      {
        // Admin preview pages are embedded as iframes inside the Rails admin —
        // omit X-Frame-Options and allow any origin via CSP frame-ancestors
        source: '/admin-preview/:path*',
        headers: [
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Content-Security-Policy',
            value: "frame-ancestors *",
          },
        ],
      },
    ];
  },
  async redirects() {
    return [
      {
        source: '/journeys/:id',
        destination: '/journeys/:id/step/1',
        permanent: true,
      },
      {
        source: '/journeys/:id/step',
        destination: '/journeys/:id/step/1',
        permanent: true,
      },
    ];
  },
  i18n: {
    locales: locales.map(({ locale }) => locale),
    defaultLocale: locales.find((locale) => locale.default).locale,
  },
  // Note: publicRuntimeConfig is deprecated in Next.js 16+, use environment variables directly
  env: {
    TxNativePublicToken: NEXT_PUBLIC_TRANSIFEX_TOKEN,
    apiHost: NEXT_PUBLIC_API_HOST || 'http://localhost:3001',
  },
};

module.exports = nextConfig;
