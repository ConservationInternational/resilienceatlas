/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'standalone',
  poweredByHeader: false,
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
};

module.exports = nextConfig;
