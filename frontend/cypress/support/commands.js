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
  cy.intercept('/api/journeys', { middleware: true }, disableRequestCache).as('journeyListRequest');
  cy.intercept({ method: 'GET', url: '/api/journeys/*', middleware: true }, (req) => {
    req.on('before:response', (res) => {
      // force all API responses to not be cached
      res.headers['cache-control'] = 'no-store';
    });
  }).as('journeyDetailRequest');

  cy.intercept(
    { method: 'GET', url: '/api/layer-groups', middleware: true },
    disableRequestCache,
  ).as('layerGroupsAPIRequest');

  cy.intercept({ method: 'GET', url: '/api/layers*', middleware: true }, disableRequestCache).as(
    'layersAPIRequest',
  );
});

Cypress.on('uncaught:exception', () => {
  // returning false here prevents Cypress from
  // failing the test

  // TODO: i18n is causing some unexpected error in the cy.visit. This doesn't affect the real application or the tests
  // But maybe there is a way to reduce the scope of this return false
  return false;

  // if (err.message.includes('canceled by the user')) {
  //   return false;
  // }
  // // axios abort error not considered an error
  // if (err.message.includes('Request aborted')) {
  //   return false;
  // }
});
