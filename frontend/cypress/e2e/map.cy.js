describe('Map page', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.wait('@siteRequest');
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container.leaflet-container');
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
