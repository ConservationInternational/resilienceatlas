const { defineConfig } = require('cypress');

module.exports = defineConfig({
  defaultCommandTimeout: 10000,
  requestTimeout: 30000,
  responseTimeout: 30000,
  execTimeout: 60000,
  hosts: {
    '*.localhost': '127.0.0.1',
  },
  e2e: {
    baseUrl: 'http://localhost:3000',
    screenshotOnRunFailure: true,
    video: false,
    viewportWidth: 1280,
    viewportHeight: 920,
  },
});
