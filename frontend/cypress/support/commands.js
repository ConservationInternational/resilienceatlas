// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

const disableRequestCache = (req) => {
  req.on('before:response', (res) => {
    // force all API responses to not be cached
    res.headers['cache-control'] = 'no-store';
  });
};

Cypress.Commands.add('interceptAllRequests', () => {
  cy.log('Intercepting requests');

  cy.intercept('/api/site', { middleware: true }, disableRequestCache).as('siteRequest');

  cy.intercept('/api/menu-entries').as('menuEntriesRequest');

  cy.intercept('/api/journeys', { middleware: true }, disableRequestCache).as('journeyListRequest');

  cy.intercept('/api/layer-groups', { middleware: true }, disableRequestCache).as(
    'layerGroupsAPIRequest',
  );

  cy.intercept('GET', '/api/layers*').as('layersAPIRequest');
});

Cypress.on('uncaught:exception', (err, runnable) => {
  // returning false here prevents Cypress from
  // failing the test
  if (err.message.includes('canceled by the user')) {
    return false;
  }
});
