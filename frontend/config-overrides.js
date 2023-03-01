const path = require('path');

/* eslint-disable no-param-reassign */
module.exports = {
  webpack(config, env) {
    // Aliases
    config.resolve.alias = {
      ...config.resolve.alias,
      '@modules': path.resolve(__dirname, 'src/state/modules/'),
      '@views': path.resolve(__dirname, 'src/views/'),
      '@state': path.resolve(__dirname, 'src/state/'),
      '@components': path.resolve(__dirname, 'src/views/components/'),
      '@contexts': path.resolve(__dirname, 'src/views/contexts/'),
      '@shared': path.resolve(__dirname, 'src/views/shared'),
      '@utilities': path.resolve(__dirname, 'src/utilities/'),
    };

    config.externals = Object.assign(config.externals || {}, {
      leaflet: 'L',
    });

    return config;
  },
};
/* eslint-enable no-param-reassign */
