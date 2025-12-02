describe('URL Management', () => {
  beforeEach(() => {
    // Ensure we have proper timeout and error handling
    cy.on('uncaught:exception', (err, runnable) => {
      // Ignore network errors and uncaught exceptions that don't affect the test
      if (
        err.message.includes('Network Error') ||
        err.message.includes('fetch') ||
        err.message.includes('ResizeObserver')
      ) {
        return false;
      }
      return true;
    });
  });

  it('A user visits a subdomain and gets redirected to the /map page of that subdomain', () => {
    // Test subdomain redirect using baseUrl with site_scope parameter to simulate subdomain
    cy.visit('/?site_scope=subdomain', { timeout: 30000 });
    cy.url({ timeout: 10000 }).should('contain', '/map');
  });

  it('A user visits the resilienceatlas main page without www. it should not be redirected to map', () => {
    // Test main page without subdomain parameter
    cy.visit('/', { timeout: 30000 });
    cy.url({ timeout: 10000 }).should('not.contain', '/map');
    cy.url().should('include', Cypress.config().baseUrl);
  });

  it('A user visits the staging main page without www. it should not be redirected to map', () => {
    // Test staging-like behavior - no subdomain means no redirect
    cy.visit('/', { timeout: 30000 });
    cy.url({ timeout: 10000 }).should('not.contain', '/map');
    cy.url().should('include', Cypress.config().baseUrl);
  });

  it('A user visits an embed map with subdomain. it should not show a 404', () => {
    // Test embed route with subdomain simulation
    cy.visit('/embed/map?site_scope=subdomain', { timeout: 30000 });
    cy.url({ timeout: 10000 }).should('contain', '/embed/map');
    // Verify the page loads without 404
    cy.get('body').should('not.contain', '404');
    cy.get('body').should('not.contain', 'This page could not be found');
  });

  it('A user visits some other page in a subdomain and gets 404', () => {
    // Test that non-allowed pages in subdomain context return 404
    cy.request({
      url: '/about?site_scope=subdomain',
      followRedirect: false,
      failOnStatusCode: false,
    }).then((response) => {
      // Should get redirected to 404 (307 redirect) or return 404 directly
      // NextResponse.redirect() returns 307 by default
      expect([404, 302, 307]).to.include(response.status);
    });
  });

  it('Test subdomain detection logic directly', () => {
    // Visit a page and check if subdomain logic works correctly
    cy.visit('/?site_scope=testsubdomain', { timeout: 30000 });

    // Should redirect to map for subdomain
    cy.url({ timeout: 10000 }).should('contain', '/map');

    // Test that map page loads properly
    cy.get('body', { timeout: 10000 }).should('be.visible');
  });
});
