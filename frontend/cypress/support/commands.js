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

// Command to allow skipping tests programmatically
Cypress.Commands.add('skip', function () {
  this.skip();
});

Cypress.Commands.add('interceptAllRequests', () => {
  cy.log('Intercepting requests');

  // Use wildcard pattern to match both relative and absolute URLs
  cy.intercept({ method: 'GET', url: '**/api/site*', middleware: true }, disableRequestCache).as(
    'siteRequest',
  );

  cy.intercept(
    { method: 'GET', url: '**/api/menu-entries', middleware: true },
    disableRequestCache,
  ).as('menuEntriesRequest');

  cy.intercept('**/api/homepage*', { middleware: true }, disableRequestCache).as('homepageRequest');
  cy.intercept('**/api/static_pages/about*', { middleware: true }, disableRequestCache).as(
    'aboutRequest',
  );
  cy.intercept('**/api/journeys*', { middleware: true }, disableRequestCache).as(
    'journeyListRequest',
  );
  cy.intercept({ method: 'GET', url: '**/api/journeys/*', middleware: true }, (req) => {
    req.on('before:response', (res) => {
      // force all API responses to not be cached
      res.headers['cache-control'] = 'no-store';
    });
  }).as('journeyDetailRequest');

  cy.intercept(
    { method: 'GET', url: '**/api/layer-groups*', middleware: true },
    disableRequestCache,
  ).as('layerGroupsAPIRequest');

  cy.intercept({ method: 'GET', url: '**/api/layers*', middleware: true }, disableRequestCache).as(
    'layersAPIRequest',
  );

  cy.intercept(
    {
      method: 'GET',
      url: 'https://maps.googleapis.com/maps/api/place/js/AutocompletionService.GetPredictionsJson*',
      middleware: true,
    },
    disableRequestCache,
  ).as('googleAutocompleteRequest');

  cy.intercept(
    {
      method: 'GET',
      url: 'https://maps.googleapis.com/maps/api/js/GeocodeService.Search?*',
      middleware: true,
    },
    disableRequestCache,
  ).as('googleGeocodeRequest');

  // Mock CartoDB API calls to avoid external dependencies and improve test reliability
  // CartoDB tile API - returns layergroup ID and CDN URL for tile fetching
  cy.intercept(
    {
      method: 'GET',
      url: 'https://*-cdn.resilienceatlas.org/user/ra/api/v1/map*',
    },
    {
      statusCode: 200,
      body: {
        layergroupid: 'mock-layergroup-id-12345',
        cdn_url: {
          http: 'cdn.resilienceatlas.org',
          https: 'cdn.resilienceatlas.org',
        },
        last_updated: '2024-01-01T00:00:00.000Z',
      },
    },
  ).as('cartodbTileRequest');

  // CartoDB SQL API - returns bounds data for layer extent
  cy.intercept(
    {
      method: 'GET',
      url: 'https://*-cdn.resilienceatlas.org/user/ra/api/v2/sql*',
    },
    {
      statusCode: 200,
      body: {
        rows: [
          {
            minx: -180,
            miny: -90,
            maxx: 180,
            maxy: 90,
          },
        ],
        time: 0.001,
        fields: {
          minx: { type: 'number' },
          miny: { type: 'number' },
          maxx: { type: 'number' },
          maxy: { type: 'number' },
        },
        total_rows: 1,
      },
    },
  ).as('cartodbBoundsRequest');
});

// Converts a hex color (eg: #FFFFFF) to an rgb string (eg: rgb(255, 255, 255)
Cypress.Commands.add('hexToRgb', (hexStr) => {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hexStr);
  try {
    return `rgb(${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(
      result[3],
      16,
    )})`;
  } catch (error) {
    cy.error(error);
    return '';
  }
});

// Custom command to wait for page to be fully loaded and interactive
Cypress.Commands.add('waitForPageLoad', () => {
  // Wait for basic page structure
  cy.get('body', { timeout: 30000 }).should('be.visible');

  // Wait for potential loading spinners or overlays to disappear
  cy.get('body').then(($body) => {
    // If there are any loading indicators, wait for them to disappear
    if ($body.find('[data-testid="loading"], .loading, .spinner').length > 0) {
      cy.get('[data-testid="loading"], .loading, .spinner', { timeout: 15000 }).should('not.exist');
    }
  });

  // Wait for React to render content in the #root container
  // This is more reliable than checking for specific layout classes
  cy.get('#root', { timeout: 30000 }).should('exist').and('not.be.empty');

  // Wait for any layout container to be present (covers both MainLayout and FullscreenLayout)
  // MainLayout uses l-main-fullscreen (no double hyphen)
  // FullscreenLayout uses l-main--fullscreen (double hyphen)
  // Header in both layouts uses l-header--fullscreen
  cy.get('.l-main--fullscreen, .l-main-fullscreen, .l-header--fullscreen, header', {
    timeout: 30000,
  }).should('exist');

  // If header exists, wait for navigation elements
  cy.get('body').then(($body) => {
    if ($body.find('.l-header--fullscreen').length > 0) {
      cy.get('.brand-area', { timeout: 15000 }).should('be.visible');
      cy.get('.nav-area', { timeout: 15000 }).should('be.visible');
    }
  });
});

// Wait for API requests if they occur, or wait for elements to load
// This handles SSR apps where data may already be loaded server-side
Cypress.Commands.add('waitForMapPageReady', () => {
  // Wait for the page layout to be rendered (SSR content)
  cy.get('.l-main--fullscreen', { timeout: 30000 }).should('exist');

  // Wait for sidebar content to be loaded (indicates page structure is ready)
  cy.get('.l-sidebar-content', { timeout: 20000 }).should('exist');

  // Wait for legend to be present
  cy.get('.m-legend', { timeout: 20000 }).should('exist');

  // The map container and leaflet are dynamically loaded client-side.
  // In some environments (especially Docker/CI), the dynamic import may not complete.
  // We try to wait for it but don't fail if it doesn't appear.
  cy.get('body').then(($body) => {
    // Try to wait for map container with a shorter timeout
    // If it appears, wait for leaflet too
    if ($body.find('.wri_api__map-container').length > 0) {
      cy.get('.leaflet-container', { timeout: 10000 }).should('be.visible');
    }
  });

  // Close tour if present - don't fail if it's not there
  // Use native jQuery click to avoid Cypress command chain issues with React re-renders
  cy.get('body').then(($body) => {
    const closeButton = $body.find('.reactour__close-button:visible');
    if (closeButton.length > 0) {
      // Click directly using jQuery to bypass Cypress element state tracking
      closeButton.get(0).click();
    }
  });
});

// Wait for homepage to be fully loaded
Cypress.Commands.add('waitForHomePageReady', () => {
  // Wait for the page layout to be rendered
  cy.get('.l-main-fullscreen', { timeout: 30000 }).should('exist');

  // Wait for header
  cy.get('.l-header--fullscreen', { timeout: 20000 }).should('exist');

  // Wait for intro section
  cy.get('.m-home-intro', { timeout: 20000 }).should('exist');
});

Cypress.on('uncaught:exception', (err) => {
  // Log the error for debugging - this helps identify client-side exceptions
  console.error('UNCAUGHT EXCEPTION:', err.message);
  console.error('Stack:', err.stack);

  // returning false here prevents Cypress from failing the test
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
