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

  cy.intercept({ method: 'GET', url: '/api/site', middleware: true }, disableRequestCache).as(
    'siteRequest',
  );

  cy.intercept(
    { method: 'GET', url: '/api/menu-entries', middleware: true },
    disableRequestCache,
  ).as('menuEntriesRequest');

  // TODO: remove comments when API is ready
  // cy.intercept(
  //   {
  //     url: '/static-journeys/journeysPageIndex.json',
  //     method: 'GET',
  //     middleware: true,
  //   },
  //   disableRequestCache,
  // ).as('journeyListRequest');
  // cy.intercept({ method: 'GET', url: '/static-journeys/1.json', middleware: true }, (req) => {
  //   req.on('before:response', (res) => {
  //     // force all API responses to not be cached
  //     res.headers['cache-control'] = 'no-store';
  //   });
  // }).as('journeyDetailRequest');
  cy.intercept('/api/journeys', { middleware: true }, disableRequestCache).as('journeyListRequest');

  cy.intercept(
    { method: 'GET', url: '/api/layer-groups', middleware: true },
    disableRequestCache,
  ).as('layerGroupsAPIRequest');

  cy.intercept({ method: 'GET', url: '/api/layers*', middleware: true }, disableRequestCache).as(
    'layersAPIRequest',
  );
});

Cypress.on('uncaught:exception', (err) => {
  // returning false here prevents Cypress from
  // failing the test
  if (err.message.includes('canceled by the user')) {
    return false;
  }
});
