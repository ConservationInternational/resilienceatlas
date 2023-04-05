describe('Home page', () => {
  beforeEach(() => {
    cy.visit('/en/');
  });

  it('should have a welcome message', () => {
    cy.get('.m-welcome').find('h3').should('contain', 'Welcome to');
    cy.get('.m-welcome').find('h2').should('contain', 'RESILIENCE ATLAS');
  });

  it('in journeys section should have a link to the journeys page', () => {
    cy.get('.m-discover__bottom')
      .find('a.btn-primary[href="/en/journeys/"]')
      .should('contain', 'More journeys')
      .click();
    cy.location('pathname').should('eq', '/en/journeys/');
  });

  it('in explore section should have a link to the map page', () => {
    cy.get('.m-explore')
      .find('a.btn-primary[href="/en/map/"]')
      .should('contain', 'Go to the map')
      .click();
    cy.location('pathname').should('eq', '/en/map/');
  });

  it('in about section should have a link to the about page', () => {
    cy.get('.m-home-about')
      .find('a.btn-primary[href="/en/about/"]')
      .should('contain', 'Learn more')
      .click();
    cy.location('pathname').should('eq', '/en/about/');
  });

  it('in about section should have a link to the map page', () => {
    cy.get('.m-home-about')
      .find('a.btn-primary[href="/en/map/"]')
      .should('contain', 'Analysing the data')
      .click();
    cy.location('pathname').should('eq', '/en/map/');
  });
});
