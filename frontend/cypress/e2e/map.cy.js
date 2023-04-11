import shareUrlEncodeFixture from '../fixtures/share-url-decode.json';

describe('Map page', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/map');
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
    cy.interceptAllRequests();
    cy.visit(
      '/map?tab=layers&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=3&center=lat%3D21.94304553343818%26lng%3D-16.699218750000004',
    );
    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');
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
    cy.interceptAllRequests();
    // url with layer id 1429
    cy.visit('/map?tab=layers&layers=%5B%7B"id"%3A1429%2C"opacity"%3A1%2C"order"%3Anull%7D%5D');
    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');
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
    cy.visit(
      '/map?tab=&center=lat%3D14.214466896745083%26lng%3D28.242759704589844&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=4',
    );

    cy.wait('@siteRequest');
    cy.wait('@layerGroupsAPIRequest');
    cy.wait('@layersAPIRequest');

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
