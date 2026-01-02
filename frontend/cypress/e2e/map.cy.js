import shareUrlDecodeFixture from '../fixtures/share-url-decode.json';

describe('Map page', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');

    // Wait for critical API calls and verify they succeeded
    cy.wait('@siteRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load - this checks for header/layout elements
    cy.waitForPageLoad();

    // Wait for map container to be available
    cy.get('.wri_api__map-container', { timeout: 30000 }).should('exist');

    // Wait for all critical map elements to be present
    cy.get('.wri_api__map-controls-list', { timeout: 20000 }).should('exist');
    cy.get('.m-legend', { timeout: 20000 }).should('exist');
    cy.get('.l-sidebar-content', { timeout: 20000 }).should('exist');

    // Remove map tour if present - don't fail if it's not there
    cy.get('body').then(($body) => {
      if ($body.find('.reactour__close-button').length > 0) {
        cy.get('.reactour__close-button').click();
      }
    });

    // Wait for map to be fully rendered
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');
  });

  it('should have a map', () => {
    cy.wait('@siteRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Verify both map container and leaflet are present
    cy.get('.wri_api__map-container').should('exist');
    cy.get('.leaflet-container').should('be.visible');
  });
});

// Checking map page with specific params in the URL
describe('Specific map page', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit(
      '/map?tab=layers&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=3&center=lat%3D21.94304553343818%26lng%3D-16.699218750000004',
    );
    cy.wait('@siteRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Wait for map container and critical elements first
    cy.get('.wri_api__map-container', { timeout: 30000 }).should('exist');
    cy.get('.wri_api__map-controls-list', { timeout: 20000 }).should('exist');
    cy.get('.m-legend', { timeout: 20000 }).should('exist');
    cy.get('.l-sidebar-content', { timeout: 20000 }).should('exist');

    // Close tour if present
    cy.get('body').then(($body) => {
      if ($body.find('.reactour__close-button').length > 0) {
        cy.get('.reactour__close-button').click();
      }
    });
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container').should('exist');
    cy.get('.leaflet-container').should('be.visible');
  });

  it('should have a layer in the legend', () => {
    cy.get('ul.m-legend__list', { timeout: 10000 }).should('exist');
    cy.get('ul.m-legend__list').find('li.drag-items', { timeout: 10000 }).should('have.length', 1);
  });

  it('should have an active layer in the sidebar', () => {
    cy.get('#layer_66', { timeout: 10000 }).should('be.checked');
  });
});

describe('Analysis should work for Livelihoods zones layer', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    // url with layer id 1429
    cy.visit('/map?tab=layers&layers=%5B%7B"id"%3A1429%2C"opacity"%3A1%2C"order"%3Anull%7D%5D');
    cy.wait('@siteRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Wait for map container first
    cy.get('.wri_api__map-container', { timeout: 30000 }).should('exist');

    // Close tour if present
    cy.get('body').then(($body) => {
      if ($body.find('.reactour__close-button').length > 0) {
        cy.get('.reactour__close-button').click();
      }
    });
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container').should('exist');
    cy.get('.leaflet-container').should('be.visible');
  });

  it('should have a layer in the legend', () => {
    cy.get('ul.m-legend__list', { timeout: 10000 }).should('exist');
    cy.get('ul.m-legend__list').find('li.drag-items', { timeout: 10000 }).should('have.length', 1);
  });

  it('should have a source in the layer', () => {
    cy.get('ul.m-legend__list', { timeout: 10000 }).should('exist');
    cy.get('ul.m-legend__list')
      .find('li.drag-items .source', { timeout: 10000 })
      .should('have.length', 1);
  });

  it('should have an active layer in the sidebar', () => {
    cy.get('#layer_1429', { timeout: 10000 }).should('be.checked');
  });

  it('should be able to open analysis', () => {
    cy.get('.btn-analysis-panel-expand', { timeout: 10000 }).should('exist').click();
    cy.get('#analysisPanelView', { timeout: 10000 }).should('be.visible');
  });
});

describe('Share modal should show shorten URL', () => {
  const shareUid = shareUrlDecodeFixture.data.attributes.uid;
  const shortenUrl = `http://localhost:3000/share/${shareUid}`;

  beforeEach(() => {
    cy.interceptAllRequests();

    cy.intercept('POST', '/api/share', {
      fixture: 'share-url-encode.json',
    }).as('shareEncodeRequest');

    cy.intercept('GET', `/api/share/${shareUid}`, {
      fixture: 'share-url-decode.json',
    }).as('shareDecodeRequest');
  });

  it('should show shorten URL', () => {
    cy.clearCookies();

    cy.visit(
      '/map?tab=&center=lat%3D14.214466896745083%26lng%3D28.242759704589844&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=4',
    );

    cy.wait('@siteRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Wait for map container first
    cy.get('.wri_api__map-container', { timeout: 15000 }).should('exist');

    // Close tour if present
    cy.get('body').then(($body) => {
      if ($body.find('.reactour__close-button').length > 0) {
        cy.get('.reactour__close-button').click();
      }
    });

    cy.get('.leaflet-container', { timeout: 10000 }).should('be.visible');

    // Click share button and test modal
    cy.get('.btn-share', { timeout: 10000 }).should('exist').click();
    cy.wait(1000);
    cy.get('.m-share', { timeout: 10000 }).should('be.visible');
    cy.get('input.url', { timeout: 10000 }).should('have.value', shortenUrl);
  });

  // Skip this test - share page redirect happens server-side and cannot be intercepted by Cypress
  // The server-side getServerSideProps makes a direct API call that bypasses Cypress intercepts
  it.skip('should load the correct url and map given a short url', () => {
    // This test is skipped because:
    // 1. The /share/[id] page uses getServerSideProps which makes a server-side API call
    // 2. Cypress can only intercept client-side requests, not server-side ones
    // 3. Without actual backend data, this test will always fail with 404
    cy.visit(`/share/${shareUid}`, { failOnStatusCode: false });

    // waiting redirect
    cy.wait(1000);

    cy.wait('@siteRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 20000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Wait for map to render properly
    cy.get('.wri_api__map-container', { timeout: 15000 }).should('exist');
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');
  });
});

describe('Map tour should be shown only once', () => {
  beforeEach(() => {
    cy.clearCookies(); // This ensures tour will show since it depends on cookies
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.wait('@siteRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Ensure map is loaded first
    cy.get('.wri_api__map-container', { timeout: 30000 }).should('exist');
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');

    // Wait for all tour target elements to be available
    cy.get('.wri_api__map-controls-list', { timeout: 20000 }).should('exist');
    cy.get('.m-legend', { timeout: 20000 }).should('exist');
    cy.get('.l-sidebar-content', { timeout: 20000 }).should('exist');
    cy.get('.btn-analysis-panel-expand', { timeout: 20000 }).should('exist');
  });

  it('should show map tour', () => {
    // Tour should appear because we cleared cookies and all target elements are present
    cy.get('.map-tour-popover', { timeout: 15000 }).should('exist');
  });

  it('should have 4 steps', () => {
    // Verify tour is visible first
    cy.get('.map-tour-popover', { timeout: 15000 }).should('exist');

    // Navigate through tour steps
    cy.get('button[data-testid="map-tour-next-button"]', { timeout: 10000 })
      .should('be.visible')
      .click();
    cy.wait(500);

    cy.get('button[data-testid="map-tour-next-button"]', { timeout: 10000 })
      .should('be.visible')
      .click();
    cy.wait(500);

    cy.get('button[data-testid="map-tour-next-button"]', { timeout: 10000 })
      .should('be.visible')
      .click();
    cy.wait(500);

    // On last step, should have close button
    cy.get('button[data-testid="map-tour-close-button"]', { timeout: 10000 })
      .should('be.visible')
      .click();

    // Tour should be gone
    cy.get('.map-tour-popover').should('not.exist');
  });

  it('should skip map tour', () => {
    // Verify tour is visible first
    cy.get('.map-tour-popover', { timeout: 15000 }).should('exist');

    cy.get('button[data-testid="map-tour-skip-button"]', { timeout: 10000 })
      .should('be.visible')
      .click();
    cy.get('.map-tour-popover', { timeout: 5000 }).should('not.exist');
  });

  it('should close map tour clicking on the x icon', () => {
    // Verify tour is visible first
    cy.get('.map-tour-popover', { timeout: 15000 }).should('exist');

    cy.get('.reactour__close-button', { timeout: 10000 }).should('be.visible').click();
    cy.get('.map-tour-popover', { timeout: 5000 }).should('not.exist');
  });
});

describe('Search box should allow cities and coordinates', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();

    cy.visit('/map');

    cy.wait('@siteRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layerGroupsAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
    cy.wait('@layersAPIRequest', { timeout: 30000 }).then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });

    // Wait for page to fully load
    cy.waitForPageLoad();

    // Wait for map container first
    cy.get('.wri_api__map-container', { timeout: 30000 }).should('exist');

    // Close tour if present
    cy.get('body').then(($body) => {
      if ($body.find('.reactour__close-button').length > 0) {
        cy.get('.reactour__close-button').click();
      }
    });
    cy.get('.leaflet-container', { timeout: 15000 }).should('be.visible');
  });

  it('should allow to search for a city', () => {
    cy.get('.m-toolbar-item--button', { timeout: 10000 }).should('exist').click();
    cy.get('.search-combobox-input', { timeout: 10000 }).should('be.visible').type('Madrid');
    cy.wait(500); // waiting for debounce
    cy.wait('@googleAutocompleteRequest'); // waiting for the autocomplete
    cy.get('.search-combobox-options', { timeout: 10000 }).should('be.visible');
    cy.get('.search-combobox-options').find('li').should('have.length', 5);
    cy.get('.search-combobox-input').type('{enter}');
    cy.get('.search-combobox-input').should('not.exist');
    cy.wait('@googleGeocodeRequest'); // waiting for the geocode
    cy.url().should('include', 'lat%3D40.437').should('include', 'lng%3D-3.67');
  });

  it('should allow to search for coordinates', () => {
    cy.get('.m-toolbar-item--button', { timeout: 10000 }).should('exist').click();
    cy.get('.search-combobox-input', { timeout: 10000 }).should('be.visible').type('-3, 40');
    cy.wait(500); // waiting for debounce
    cy.get('.search-combobox-input-coordinates', { timeout: 10000 }).should('be.visible');
    cy.get('.search-combobox-input').type('{enter}');
    cy.get('.search-combobox-input').should('not.exist');
    cy.wait('@googleGeocodeRequest'); // waiting for the geocode
    cy.url().should('include', 'lat%3D40');
  });
});
