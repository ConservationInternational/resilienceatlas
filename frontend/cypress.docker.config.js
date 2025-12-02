const { defineConfig } = require('cypress');

module.exports = defineConfig({
  defaultCommandTimeout: 15000,
  requestTimeout: 30000,
  responseTimeout: 30000,
  execTimeout: 60000,
  pageLoadTimeout: 60000,
  // Remove localhost host mapping for Docker environment
  hosts: {},
  e2e: {
    specPattern: '**/*.cy.js',
    // Use frontend-test service URL for Docker environment
    baseUrl: 'http://frontend-test:3000',
    screenshotOnRunFailure: true,
    video: false,
    viewportWidth: 1280,
    viewportHeight: 920,
    // Skip URL tests that rely on localhost subdomains in Docker environment
    excludeSpecPattern: [
      '**/url.cy.js',
      // Also exclude any other tests that might have hardcoded localhost URLs
      '**/integration/unit.cy.js',
      '**/unit/unit.cy.js',
    ],
  },
  reporter: 'junit',
  reporterOptions: {
    mochaFile: 'cypress/results/test-results-[hash].xml',
    toConsole: true,
  },
});
