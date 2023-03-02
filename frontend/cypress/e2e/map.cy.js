describe('Map page', () => {
  beforeEach(() => {
    cy.visit('/map');
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container.leaflet-container');
  });
});

// Checking map page with specific params in the URL
describe('Specific map page', () => {
  beforeEach(() => {
    cy.intercept({
      method: 'GET',
      pathname: '/user/ra/api/v2/sql',
    }).as('cartoRequest');

    cy.intercept('GET', '/api/layers*').as('layersAPIRequest');

    cy.visit(
      '/map?tab=layers&layers=%5B%7B"id"%3A66%2C"opacity"%3A1%2C"order"%3Anull%7D%5D&zoom=3&center=lat%3D21.94304553343818%26lng%3D-16.699218750000004',
    );
  });

  it('should have a map', () => {
    cy.get('.wri_api__map-container.leaflet-container');
  });

  it('should have a layer in the legend', () => {
    cy.wait('@layersAPIRequest');
    cy.get('ul.m-legend__list')
      .find('li.drag-items')
      .should('have.length', 1);
    cy.wait('@cartoRequest');
  });

  it('should have an active layer in the sidebar', () => {
    cy.wait('@layersAPIRequest');
    cy.get('#layer_66').should('be.checked');
  });
});
