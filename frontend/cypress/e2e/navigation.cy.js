describe('Navigation', () => {
  it('should navigate to the home page', () => {
    cy.visit('/');
    cy.location('pathname').should('eq', '/');
  });

  it('should navigate to the map page', () => {
    cy.visit('/map');
    cy.location('pathname').should('eq', '/map');
  });

  it('should navigate to the about page', () => {
    cy.visit('/about');
    cy.location('pathname').should('eq', '/about');
  });

  it('should navigate to the journeys page', () => {
    cy.visit('/journeys');
    cy.location('pathname').should('eq', '/journeys');
  });
});
