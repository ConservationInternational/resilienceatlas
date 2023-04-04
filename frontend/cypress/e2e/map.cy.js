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
