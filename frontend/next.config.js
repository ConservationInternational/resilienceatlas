const { locales } = require('./locales.config.json');

const { NEXT_PUBLIC_TRANSIFEX_TOKEN, NEXT_PUBLIC_API_HOST } = process.env;

// Determine if we're in production based on API host
const isProduction = NEXT_PUBLIC_API_HOST && NEXT_PUBLIC_API_HOST.includes('resilienceatlas.org');
const isStaging = NEXT_PUBLIC_API_HOST && NEXT_PUBLIC_API_HOST.includes('staging');

/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  // Enable trailing slash for better subdomain handling
  trailingSlash: false,
  // Note: ESLint is now configured via eslint.config.mjs (ESLint 9 flat config)
  // The 'eslint' option was removed in Next.js 16. Use `npm run lint` directly.
  typescript: {
    // !! WARN !!
    // Dangerously allow production builds to successfully complete even if
    // your project has type errors.
    // !! WARN !!
    ignoreBuildErrors: true,
  },
  // Next.js 16+ uses experimental.serverActions instead of serverExternalPackages
  serverExternalPackages: [],
  async headers() {
    return [
      {
        // Apply headers to all routes
        source: '/(.*)',
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
