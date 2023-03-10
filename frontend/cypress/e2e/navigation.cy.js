describe('Main menu', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('clicking on the logo should navigate to the home page', () => {
    cy.get('.brand-area')
      .find('a')
      .click();
    cy.location('pathname').should('eq', '/');
  });

  it('clicking on "Journeys" should navigate to the journeys page', () => {
    cy.get('.nav-area')
      .find('a[href="/journeys"]')
      .click();
    cy.location('pathname').should('eq', '/journeys');
  });

  it('clicking on "About" should navigate to the about page', () => {
    cy.get('.nav-area')
      .find('a[href="/about"]')
      .click();
    cy.location('pathname').should('eq', '/about');
  });

  it('clicking on "Map" should navigate to the map page', () => {
    cy.get('.nav-area')
      .find('a[href="/map"]')
      .click();
    cy.location('pathname').should('eq', '/map');
  });
});
