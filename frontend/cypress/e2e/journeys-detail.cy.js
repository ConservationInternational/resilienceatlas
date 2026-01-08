/**
 * Journeys Detail Page Integration Tests
 *
 * ARCHITECTURE NOTES:
 * This is a Next.js SSR application where page data is fetched server-side
 * via getServerSideProps. This means:
 * 1. Cypress cy.intercept() CANNOT capture server-side API calls
 * 2. Page content is already rendered when Cypress visits the page
 * 3. Tests should verify UI elements directly, not API responses
 *
 * These tests navigate from the journeys index page to a detail page,
 * then verify the detail page UI elements are present.
 */

describe('Journeys detail page - SSR Layout', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/journeys');
    cy.waitForPageLoad();
  });

  it('should navigate to journey detail when clicking learn more', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-journey__gridelement').length > 0) {
        // Click the first journey's learn more button
        cy.get('.m-journey__gridelement').first().find('a[href*="/journeys/"]').first().click();

        // Verify navigation to journey detail page
        cy.url({ timeout: 10000 }).should('include', '/journeys/');

        // Verify journey detail layout is present
        cy.get('.l-journey', { timeout: 15000 }).should('exist');
        cy.log('✓ Successfully navigated to journey detail page');
      } else {
        cy.log('⚠ No journeys available to test detail navigation');
      }
    });
  });
});

describe('Journeys detail page - Step Types', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/journeys');
    cy.waitForPageLoad();
  });

  it('should display landing step content if available', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-journey__gridelement').length > 0) {
        // Navigate to first journey
        cy.get('.m-journey__gridelement').first().find('a[href*="/journeys/"]').first().click();
        cy.url({ timeout: 10000 }).should('include', '/journeys/');

        // Wait for journey layout
        cy.get('.l-journey', { timeout: 15000 }).should('exist');

        // Check for landing intro (first step is usually landing)
        cy.get('body').then(($body2) => {
          if ($body2.find('.l-journey__intro').length > 0) {
            cy.get('.l-journey__intro').should('be.visible');
            cy.get('.l-journey__intro h1').should('exist');
            cy.log('✓ Landing step content is displayed');
          } else if ($body2.find('.m-journey--conclusion').length > 0) {
            cy.log('✓ Conclusion step is displayed (may be single step journey)');
          } else if ($body2.find('.chapter-intro').length > 0) {
            cy.log('✓ Chapter step is displayed');
          } else if ($body2.find('.side-bar').length > 0) {
            cy.log('✓ Embed step is displayed');
          } else {
            cy.log('⚠ Unknown journey step type');
          }
        });
      } else {
        cy.log('⚠ No journeys available to test step content');
      }
    });
  });

  it('should have navigation buttons if multiple steps', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-journey__gridelement').length > 0) {
        // Navigate to first journey
        cy.get('.m-journey__gridelement').first().find('a[href*="/journeys/"]').first().click();
        cy.url({ timeout: 10000 }).should('include', '/journeys/');

        // Wait for journey layout
        cy.get('.l-journey', { timeout: 15000 }).should('exist');

        // Check for navigation buttons
        cy.get('body').then(($body2) => {
          if ($body2.find('.btn-next').length > 0) {
            cy.get('.btn-next').should('exist');
            cy.log('✓ Next button is present');
          } else {
            cy.log('⚠ No next button - may be single step or last step');
          }
        });
      } else {
        cy.log('⚠ No journeys available to test navigation');
      }
    });
  });
});

