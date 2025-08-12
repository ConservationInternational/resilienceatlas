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
  eslint: {
    // Warning: This allows production builds to successfully complete even if
    // your project has ESLint errors.
    ignoreDuringBuilds: true,
  },
  typescript: {
    // !! WARN !!
    // Dangerously allow production builds to successfully complete even if
    // your project has type errors.
    // !! WARN !!
    ignoreBuildErrors: true,
  },
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
  publicRuntimeConfig: {
    TxNativePublicToken: NEXT_PUBLIC_TRANSIFEX_TOKEN,
  },
};

module.exports = nextConfig;
