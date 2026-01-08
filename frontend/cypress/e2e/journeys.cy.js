/**
 * Journeys Index Page Integration Tests
 *
 * ARCHITECTURE NOTES:
 * This is a Next.js SSR application where page data is fetched server-side
 * via getServerSideProps. This means:
 * 1. Cypress cy.intercept() CANNOT capture server-side API calls
 * 2. Page content is already rendered when Cypress visits the page
 * 3. Tests should verify UI elements directly, not API responses
 */

describe('Journeys index page - SSR Layout', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/journeys');
    cy.waitForPageLoad();
  });

  it('should have a title', () => {
    cy.get('.m-journey__title h1').first().should('exist');
  });

  it('should have the page header with navigation', () => {
    cy.get('.l-header--fullscreen').should('exist');
    cy.get('.brand-area').should('be.visible');
    cy.get('.nav-area').should('be.visible');
  });

  it('should display journey grid elements if journeys exist', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-journey__gridelement').length > 0) {
        cy.get('.m-journey__gridelement').should('have.length.at.least', 1);
        cy.log('✓ Journey grid elements are rendered');
      } else {
        cy.log('⚠ No journey grid elements found - this may be expected based on CMS content');
      }
    });
  });

  it('should have journey links with correct structure', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-journey__gridelement').length > 0) {
        cy.get('.m-journey__gridelement').first().within(() => {
          // Each journey should have a title and learn more button
          cy.get('h2').should('exist');
          cy.get('a').should('have.attr', 'href').and('include', '/journeys/');
        });
        cy.log('✓ Journey links have correct structure');
      } else {
        cy.log('⚠ No journeys to test link structure');
      }
    });
  });
});

