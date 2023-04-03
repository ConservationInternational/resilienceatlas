const { defineConfig } = require('cypress');
const getCompareSnapshotsPlugin = require('cypress-image-diff-js/dist/plugin');

module.exports = defineConfig({
  defaultCommandTimeout: 10000,
  requestTimeout: 30000,
  responseTimeout: 30000,
  execTimeout: 60000,
  e2e: {
    baseUrl: 'http://localhost:3000',
    screenshotOnRunFailure: true,
    video: false,
    viewportWidth: 1280,
    viewportHeight: 920,
    setupNodeEvents(on, config) {
      getCompareSnapshotsPlugin(on, config);
    },
  },
});
