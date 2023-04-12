const { locales } = require('./locales.config.json');

/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'standalone',
  poweredByHeader: false,
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
};

module.exports = nextConfig;
