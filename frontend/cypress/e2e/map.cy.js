import shareUrlEncodeFixture from '../fixtures/share-url-decode.json';

describe('Map page', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    // Remove map tour
    cy.get('.reactour__close-button').click();
  });

  it('should have a map', () => {
    cy.wait('@siteRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
      cy.get('.wri_api__map-container.leaflet-container');
    });
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
    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

    // Remove map tour
    cy.get('.reactour__close-button').click();
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container.leaflet-container');
  });

  it('should have a layer in the legend', () => {
    cy.get('ul.m-legend__list').find('li.drag-items').should('have.length', 1);
  });

  it('should have an active layer in the sidebar', () => {
    cy.get('#layer_66').should('be.checked');
  });
});

describe('Analysis should work for Livelihoods zones layer', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    // url with layer id 1429
    cy.visit('/map?tab=layers&layers=%5B%7B"id"%3A1429%2C"opacity"%3A1%2C"order"%3Anull%7D%5D');
    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

    // Remove map tour
    cy.get('.reactour__close-button').click();
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container.leaflet-container');
  });

  it('should have a layer in the legend', () => {
    cy.get('ul.m-legend__list').find('li.drag-items').should('have.length', 1);
  });

  it('should have a source in the layer', () => {
    cy.get('ul.m-legend__list').find('li.drag-items .source').should('have.length', 1);
  });

  it('should have an active layer in the sidebar', () => {
    cy.get('#layer_1429').should('be.checked');
  });

  it('should be able to open analysis', () => {
    cy.get('.btn-analysis-panel-expand').click();
    cy.get('#analysisPanelView').should('be.visible');
  });
});

describe('Share modal should show shorten URL', () => {
  const shortenUrl = `http://localhost:3000/share/${shareUrlEncodeFixture.attributes.uid}`;

  beforeEach(() => {
    cy.interceptAllRequests();

    cy.intercept('POST', '/api/share', {
      fixture: 'share-url-encode.json',
    }).as('shareEncodeRequest');

    cy.intercept('GET', `/api/share/${shareUrlEncodeFixture.attributes.uid}`, {
      fixture: 'share-url-decode.json',
    }).as('shareDecodeRequest');
  });

  it('should show shorten URL', () => {
    cy.clearCookies();

    cy.visit(
      '/map?tab=&center=lat%3D14.214466896745083%26lng%3D28.242759704589844&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=4',
    );

    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

    // Remove map tour
    cy.get('.reactour__close-button').click();

    cy.get('.wri_api__map-container.leaflet-container');

    cy.get('.btn-share').click();
    cy.wait(1000);
    cy.get('.m-share').should('be.visible');
    cy.get('input.url').should('have.value', shortenUrl);
  });

  it('should load the correct url and map given a short url', () => {
    cy.visit(shortenUrl);

    // waiting redirect
    cy.wait(1000);

    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

    cy.get('.wri_api__map-container.leaflet-container');
  });
});

describe('Map tour should be shown only once', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');
  });

  it('should show map tour', () => {
    cy.get('.map-tour-popover').should('exist');
  });

  it('should have 4 steps', () => {
    cy.get('button[data-testid="map-tour-next-button"]').click();
    cy.get('button[data-testid="map-tour-next-button"]').click();
    cy.get('button[data-testid="map-tour-next-button"]').click();
    cy.get('button[data-testid="map-tour-close-button"]').click();
  });

  it('should skip map tour', () => {
    cy.get('button[data-testid="map-tour-skip-button"]').click();
    cy.get('.map-tour-popover').should('not.exist');
  });

  it('should close map tour clicking on the x icon', () => {
    cy.get('.reactour__close-button').click();
    cy.get('.map-tour-popover').should('not.exist');
  });
});

describe('Search box should allow cities and coordinates', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.interceptAllRequests();

    cy.visit('/map');

    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

    // Remove map tour
    cy.get('.reactour__close-button').click();
  });

  it('should allow to search for a city', () => {
    cy.get('.m-toolbar-item--button').click();
    cy.get('.search-combobox-input').type('Madrid');
    cy.wait(500); // waiting for debounce
    cy.wait('@googleAutocompleteRequest'); // waiting for the autocomplete
    cy.get('.search-combobox-options').should('be.visible');
    cy.get('.search-combobox-options').find('li').should('have.length', 5);
    cy.get('.search-combobox-input').type('{enter}');
    cy.get('.search-combobox-input').should('not.exist');
    cy.wait('@googleGeocodeRequest'); // waiting for the geocode
    cy.url().should('include', 'lat%3D40.437').should('include', 'lng%3D-3.67');
  });

  it('should allow to search for coordinates', () => {
    cy.get('.m-toolbar-item--button').click();
    cy.get('.search-combobox-input').type('-3, 40');
    cy.wait(500); // waiting for debounce
    cy.get('.search-combobox-input-coordinates').should('be.visible');
    cy.get('.search-combobox-input').type('{enter}');
    cy.get('.search-combobox-input').should('not.exist');
    cy.wait('@googleGeocodeRequest'); // waiting for the geocode
    cy.url().should('include', 'lat%3D40');
  });
});
